using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Controllers;
using SmartAgri.Api.Data;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public class SalesAnalyticsTests
{
    [Fact]
    public void Sri_Lankan_month_boundary_and_empty_reports_are_honest()
    {
        var now = new DateTime(2026, 9, 30, 20, 0, 0, DateTimeKind.Utc);
        var period = SalesAnalytics.Period("This Month", now);
        Assert.Equal(new DateTime(2026, 9, 30, 18, 30, 0, DateTimeKind.Utc), period.Start);
        var empty = JsonSerializer.SerializeToElement(SalesAnalytics.Build(period, [], []));
        Assert.Equal(0, empty.GetProperty("categoryData").GetArrayLength());
        Assert.Equal(JsonValueKind.Null, empty.GetProperty("summary").GetProperty("netProfit").ValueKind);
        var result = JsonSerializer.SerializeToElement(SalesAnalytics.Build(period, [], [
            new(period.Start.AddTicks(-1), 999m, "Products"),
            new(period.Start, 100m, "Products"),
            new(now, 999m, "Products")
        ]));
        Assert.Equal(100, result.GetProperty("summary").GetProperty("totalRevenue").GetDecimal());
        Assert.Equal(100, result.GetProperty("monthlyData")[0].GetProperty("revenue").GetDecimal());
        Assert.Throws<ArgumentException>(() => SalesAnalytics.Period("bad", now));
    }

    [Fact]
    public async Task Payments_and_partial_balances_use_real_statuses_and_dates()
    {
        var connection = Environment.GetEnvironmentVariable("SMARTAGRI_TEST_CONNECTION");
        Assert.False(string.IsNullOrEmpty(connection), "Set SMARTAGRI_TEST_CONNECTION.");
        var builder = new NpgsqlConnectionStringBuilder(connection) {
            Database = $"smartagri_analytics_test_{Guid.NewGuid():N}", Pooling = false
        };
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql(builder.ConnectionString).Options);
        try {
            await db.Database.EnsureCreatedAsync();
            var user = new User { FullName = "Test", Email = "analytics@test.example", PasswordHash = "test", Role = "FARMER" };
            db.Users.Add(user);
            await db.SaveChangesAsync();
            var now = DateTime.UtcNow.AddMinutes(-1);
            CustomerOrder Order(string state, string payment, decimal amount, DateTime? created = null) => new() {
                UserId = user.Id, FullName = "Test", RequestId = Guid.NewGuid(),
                Status = state, TotalAmount = amount, CreatedAt = created ?? now,
                Payment = new CustomerPayment { Method = "COD", Status = payment, Amount = amount,
                    PaidAt = payment == "Paid" ? now : null }
            };
            // A paid older order still contributes to this period's collections.
            db.CustomerOrders.AddRange(
                Order("Delivered", "Paid", 100m, now.AddYears(-2)),
                Order("Confirmed", "Unpaid", 200m),
                Order("PaymentFailed", "Failed", 300m),
                Order("Cancelled", "Cancelled", 400m),
                Order("PaymentReview", "Chargeback", 500m));
            var package = new Package { Name = "Transport", Category = "TRANSPORT", CreatedById = user.Id };
            var booking = new PackageBooking { Package = package, FarmerId = user.Id,
                CreatedAt = now, TotalPrice = 1000m, AdvanceAmount = 300m, AmountPaid = 300m,
                RequiresAdvancePayment = true, PaymentStatus = "PARTIALLY_PAID", Status = "CONFIRMED" };
            var pending = new PackageBooking { Package = package, FarmerId = user.Id,
                CreatedAt = now, TotalPrice = 900m, RequiresAdvancePayment = true, PaymentStatus = "UNPAID", Status = "PENDING" };
            db.PackageBookings.AddRange(booking, pending);
            db.PackagePaymentProofs.AddRange(
                new PackagePaymentProof { Booking = booking, Amount = 300m, Stage = "ADVANCE", Status = "APPROVED", ReviewedAt = now },
                new PackagePaymentProof { Booking = booking, Amount = 700m, Stage = "BALANCE", Status = "SUBMITTED" });
            await db.SaveChangesAsync();
            var controller = new AnalyticsController(db);
            var response = Assert.IsType<OkObjectResult>(await controller.GetSalesAndProfit("This Year"));
            var report = JsonSerializer.SerializeToElement(response.Value);
            var summary = report.GetProperty("summary");
            Assert.Equal(400m, summary.GetProperty("totalRevenue").GetDecimal());
            Assert.Equal(1200m, summary.GetProperty("pendingPayments").GetDecimal());
            Assert.Equal(6, summary.GetProperty("totalOrders").GetInt32());
            Assert.Equal(400m, report.GetProperty("monthlyData").EnumerateArray().Sum(x => x.GetProperty("revenue").GetDecimal()));
            Assert.Equal(400m, report.GetProperty("categoryData").EnumerateArray().Sum(x => x.GetProperty("amount").GetDecimal()));
            var rows = report.GetProperty("recentTransactions").EnumerateArray().ToList();
            Assert.Contains(rows, r => r.GetProperty("status").GetString() == "Cancelled" && r.GetProperty("paymentStatus").GetString() == "Cancelled");
            Assert.DoesNotContain(rows, r => r.GetProperty("status").GetString() == "Refunded");
            Assert.IsType<BadRequestObjectResult>(await controller.GetSalesAndProfit("bad"));
        }
        finally { await db.Database.EnsureDeletedAsync(); }
    }
}
