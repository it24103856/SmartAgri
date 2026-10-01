using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "ADMIN")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public class AnalyticsController(ApplicationDbContext db) : ControllerBase
{
    [HttpGet("sales-profit")]
    public async Task<IActionResult> GetSalesAndProfit(
        [FromQuery] string range = "Last 6 Months", CancellationToken ct = default)
    {
        AnalyticsPeriod period;
        try { period = SalesAnalytics.Period(range, DateTime.UtcNow); }
        catch (ArgumentException) { return BadRequest(new { message = "Invalid date range." }); }

        // Collections use payment dates; order activity uses creation dates.
        var orders = await db.CustomerOrders.AsNoTracking()
            .Where(o => o.CreatedAt >= period.Start && o.CreatedAt < period.End)
            .Select(o => new AnalyticsOrder(
                "ORD-" + o.Id, o.CreatedAt, o.FullName,
                o.Items.OrderBy(i => i.Id).Select(i => i.Name).FirstOrDefault() ?? "Products",
                o.TotalAmount, o.Status, o.Payment.Status,
                o.Status != "Cancelled" && o.Status != "Rejected" && o.Status != "PaymentReview"
                    && (o.Payment.Status == "Unpaid" || o.Payment.Status == "Pending" || o.Payment.Status == "Failed")
                    ? o.TotalAmount : 0m))
            .ToListAsync(ct);
        var bookings = await db.PackageBookings.AsNoTracking()
            .Where(b => b.CreatedAt >= period.Start && b.CreatedAt < period.End)
            .Select(b => new AnalyticsOrder(
                "BKG-" + b.Id, b.CreatedAt, b.Farmer == null ? "Unknown" : b.Farmer.FullName,
                b.Package == null ? "Package" : b.Package.Name,
                b.TotalPrice, b.Status, b.PaymentStatus,
                b.RequiresAdvancePayment && (b.Status == "AWAITING_PAYMENT" || b.Status == "CONFIRMED" || b.Status == "COMPLETED")
                    && b.TotalPrice > b.AmountPaid ? b.TotalPrice - b.AmountPaid : 0m))
            .ToListAsync(ct);
        var collections = await db.CustomerOrders.AsNoTracking()
            .Where(o => o.Payment.Status == "Paid" && o.Payment.PaidAt >= period.Start && o.Payment.PaidAt < period.End)
            .Select(o => new AnalyticsCollection(o.Payment.PaidAt!.Value, o.Payment.Amount, "Products"))
            .ToListAsync(ct);
        var receipts = await db.PackagePaymentProofs.AsNoTracking()
            .Where(p => p.Status == "APPROVED" && p.ReviewedAt >= period.Start && p.ReviewedAt < period.End)
            .Select(p => new AnalyticsCollection(p.ReviewedAt!.Value, p.Amount,
                p.Booking.Package == null ? "Other services" : p.Booking.Package.Category))
            .ToListAsync(ct);
        return Ok(SalesAnalytics.Build(period, orders.Concat(bookings), collections.Concat(receipts)));
    }
}
