using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/customer-orders")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class CustomerOrderTrackingController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly CustomerCheckoutService _checkout;

    public CustomerOrderTrackingController(
        ApplicationDbContext db,
        CustomerCheckoutService checkout)
    {
        _db = db;
        _checkout = checkout;
    }

    [HttpGet("{id:int}/tracking")]
    public async Task<IActionResult> Tracking(
        int id,
        CancellationToken ct)
    {
        var userId = await _checkout.CustomerId(User);

        // Read order and history from the same database snapshot.
        await using var transaction =
            await _db.Database.BeginTransactionAsync(
                IsolationLevel.RepeatableRead,
                ct);

        var order = await _db.CustomerOrders
            .AsNoTracking()
            .Include(value => value.Items)
            .Include(value => value.Payment)
            .SingleOrDefaultAsync(
                value => value.Id == id && value.UserId == userId,
                ct);

        if (order is null)
        {
            return NotFound(new { message = "Order not found." });
        }

        var history = await _db.CustomerOrderStatusHistories
            .AsNoTracking()
            .Where(value => value.OrderId == order.Id)
            .OrderBy(value => value.CreatedAt)
            .ThenBy(value => value.Id)
            .Select(value => new
            {
                value.Id,
                value.FromStatus,
                value.ToStatus,
                value.CreatedAt,
                value.PaymentCollected,
                CancellationReason = value.ToStatus == "Cancelled"
                    ? value.Note
                    : null
            })
            .ToListAsync(ct);

        await transaction.CommitAsync(ct);

        return Ok(new
        {
            order,
            history
        });
    }
}
