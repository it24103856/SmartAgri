using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Controllers;
using SmartAgri.Api.Data;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public class FarmerReportsTests
{
    [Fact]
    public async Task Reviews_notify_owner_and_report_excludes_other_farmers_unpaid_and_cancelled_sales()
    {
        var connection = Environment.GetEnvironmentVariable("SMARTAGRI_TEST_CONNECTION");
        Assert.False(string.IsNullOrEmpty(connection), "Set SMARTAGRI_TEST_CONNECTION to a local test server.");
        var settings = new NpgsqlConnectionStringBuilder(connection) {
            Database = $"smartagri_reports_test_{Guid.NewGuid():N}", Pooling = false
        };
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql(settings.ConnectionString).Options);
        try
        {
            await db.Database.EnsureCreatedAsync();
            var farmer = new User { Email = "farmer@test.example", Role = "FARMER", PasswordHash = "test" };
            var other = new User { Email = "other@test.example", Role = "FARMER", PasswordHash = "test" };
            var admin = new User { Email = "admin@test.example", Role = "ADMIN", PasswordHash = "test" };
            var category = new Category { Name = "Vegetables", NormalizedName = "VEGETABLES" };
            db.AddRange(farmer, other, admin, category);
            await db.SaveChangesAsync();
            var product = new Product { Name = "Carrots", Category = category, Price = 999, Status = "PENDING", CreatedBy = farmer, CreatedByRole = "FARMER" };
            var otherProduct = new Product { Name = "Other", Category = category, Price = 900, CreatedBy = other, CreatedByRole = "FARMER" };
            db.AddRange(product, otherProduct);
            await db.SaveChangesAsync();
            await new ProductService(db, null!).ReviewAsync(admin.Id, product.Id, new() { Version = product.Version }, true);
            var notification = await db.FarmerNotifications.SingleAsync();
            Assert.Equal(farmer.Id, notification.FarmerId);
            Assert.Null(notification.ReadAt);
            foreach (var sale in new[] { (product.Id, "Paid", "Confirmed"), (otherProduct.Id, "Paid", "Confirmed"), (product.Id, "Unpaid", "Confirmed"), (product.Id, "Paid", "Cancelled") })
            {
                db.CustomerOrders.Add(new CustomerOrder {
                    UserId = farmer.Id, RequestId = Guid.NewGuid(), Status = sale.Item3,
                    Payment = new CustomerPayment { Status = sale.Item2, PaidAt = DateTime.UtcNow.AddMinutes(-1), Amount = 600 },
                    Items = [new CustomerOrderLine { ProductId = sale.Id, Name = "Carrots", Unit = "kg", Quantity = 3, UnitPrice = 200 }]
                });
            }
            await db.SaveChangesAsync();
            FarmerReportsController Controller(int id) => new(db) {
                ControllerContext = new() { HttpContext = new DefaultHttpContext {
                    User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString())], "test"))
                }}
            };
            var report = JsonSerializer.SerializeToElement(Assert.IsType<OkObjectResult>(await Controller(farmer.Id).Sales("This Year")).Value);
            Assert.Equal(600, report.GetProperty("totalSales").GetDecimal());
            Assert.Equal(1, report.GetProperty("totalOrders").GetInt32());
            Assert.IsType<NotFoundResult>(await Controller(other.Id).Read(notification.Id));
            Assert.IsType<NoContentResult>(await Controller(farmer.Id).Read(notification.Id));
            Assert.NotNull(notification.ReadAt);
            Assert.IsType<BadRequestObjectResult>(await Controller(farmer.Id).Sales("invalid"));
        }
        finally { await db.Database.EnsureDeletedAsync(); }
    }
}
