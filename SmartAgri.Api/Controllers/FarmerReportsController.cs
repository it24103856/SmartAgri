using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/farmer-reports")]
[Authorize(Roles = "FARMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class FarmerReportsController(ApplicationDbContext db) : ControllerBase
{
    private int FarmerId => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
    private Task<bool> Active() => db.Users.AnyAsync(u => u.Id == FarmerId && u.Role == "FARMER" && u.Status == "ACTIVE");

    [HttpGet("notifications")]
    public async Task<IActionResult> Notifications([FromQuery] int page = 1)
    {
        if (!await Active()) return Forbid();
        if (page < 1 || page > 10000) return BadRequest(new { message = "Invalid page." });
        var query = db.FarmerNotifications.AsNoTracking().Where(n => n.FarmerId == FarmerId);
        return Ok(new {
            unreadCount = await query.CountAsync(n => n.ReadAt == null),
            totalCount = await query.CountAsync(),
            items = await query.OrderByDescending(n => n.CreatedAt).ThenByDescending(n => n.Id)
                .Skip((page - 1) * 30).Take(30).ToListAsync()
        });
    }

    [HttpPut("notifications/{id:int}/read")]
    public async Task<IActionResult> Read(int id)
    {
        if (!await Active()) return Forbid();
        var item = await db.FarmerNotifications.SingleOrDefaultAsync(n => n.Id == id && n.FarmerId == FarmerId);
        if (item is null) return NotFound();
        item.ReadAt ??= DateTime.UtcNow;
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpGet("sales")]
    public async Task<IActionResult> Sales([FromQuery] string range = "This Month")
    {
        if (!await Active()) return Forbid();
        AnalyticsPeriod period;
        try { period = SalesAnalytics.Period(range, DateTime.UtcNow); }
        catch (ArgumentException) { return BadRequest(new { message = "Invalid report range." }); }
        // Use payment date and checkout prices; exclude cancelled/refunded orders.
        var rows = await (from line in db.CustomerOrderLines.AsNoTracking()
                          join product in db.Products on line.ProductId equals product.Id
                          join order in db.CustomerOrders on line.OrderId equals order.Id
                          where product.CreatedById == FarmerId && product.CreatedByRole == "FARMER"
                              && order.Payment.Status == "Paid" && order.Status != "Cancelled"
                              && order.Payment.PaidAt >= period.Start && order.Payment.PaidAt < period.End
                          select new { line.ProductId, line.Name, line.Unit, line.Quantity, line.UnitPrice, line.OrderId })
            .ToListAsync();
        var products = rows.GroupBy(r => new { r.ProductId, r.Name, r.Unit }).Select(g => new {
            g.Key.ProductId, g.Key.Name, g.Key.Unit,
            quantity = g.Sum(r => r.Quantity), orders = g.Select(r => r.OrderId).Distinct().Count(),
            sales = g.Sum(r => r.Quantity * r.UnitPrice)
        }).OrderByDescending(r => r.sales).ToArray();
        return Ok(new {
            range, from = period.Start, to = period.End, timezone = "Asia/Colombo",
            totalSales = rows.Sum(r => r.Quantity * r.UnitPrice),
            totalOrders = rows.Select(r => r.OrderId).Distinct().Count(), products
        });
    }
}
