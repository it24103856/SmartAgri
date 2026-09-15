using System.Data;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class CustomerOrderCancellationService
{
    private readonly ApplicationDbContext _db;

    public CustomerOrderCancellationService(ApplicationDbContext db)
    {
        _db = db;
    }

    private static bool IsConflict(Exception error)
    {
        if (error is DbUpdateConcurrencyException)
            return true;

        if (error is PostgresException postgres
            && postgres.SqlState is "40001" or "40P01")
        {
            return true;
        }

        return error.InnerException is not null
            && IsConflict(error.InnerException);
    }

    public async Task Cancel(
        int userId,
        int orderId,
        string reason,
        CancellationToken ct)
    {
        reason = reason.Trim();

        if (reason.Length < 5 || reason.Length > 500)
        {
            throw new BadHttpRequestException(
                "Enter a cancellation reason between 5 and 500 characters.");
        }

        await using var transaction =
            await _db.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                ct);

        try
        {
            var order = await _db.CustomerOrders
                .Include(value => value.Items)
                .Include(value => value.Payment)
                .SingleOrDefaultAsync(
                    value => value.Id == orderId
                        && value.UserId == userId,
                    ct)
                ?? throw new BadHttpRequestException(
                    "Order not found.", 404);

            // A repeated request must not restore stock a second time.
            if (order.Status == "Cancelled"
                && order.Payment.Method == "COD"
                && order.Payment.Status == "Cancelled")
            {
                await transaction.CommitAsync(ct);
                return;
            }

            if (order.Payment.Method != "COD"
                || order.Payment.Status != "Unpaid")
            {
                throw new BadHttpRequestException(
                    "Only unpaid Cash on Delivery orders can be cancelled here.",
                    409);
            }

            if (order.Status != "Confirmed")
            {
                throw new BadHttpRequestException(
                    "This order can no longer be cancelled because its status changed.",
                    409);
            }

            // Grouping also protects against duplicate product lines.
            var quantities = order.Items
                .GroupBy(item => item.ProductId)
                .ToDictionary(
                    group => group.Key,
                    group => group.Sum(item => (long)item.Quantity));

            var productIds = quantities.Keys.ToArray();

            var products = await _db.Products
                .Where(product => productIds.Contains(product.Id))
                .ToDictionaryAsync(product => product.Id, ct);

            // Validate all stock changes before applying any of them.
            foreach (var entry in quantities)
            {
                if (!products.TryGetValue(entry.Key, out var product))
                {
                    throw new BadHttpRequestException(
                        "A product record is missing. Contact support to cancel this order.",
                        409);
                }

                var restored = (long)product.StockQuantity + entry.Value;

                if (entry.Value <= 0 || restored < 0 || restored > int.MaxValue)
                {
                    throw new BadHttpRequestException(
                        "Stock could not be restored. Contact support.",
                        409);
                }
            }

            foreach (var entry in quantities)
            {
                var product = products[entry.Key];

                product.StockQuantity =
                    (int)((long)product.StockQuantity + entry.Value);

                product.Version = Guid.NewGuid();
            }

            order.Status = "Cancelled";
            order.Payment.Status = "Cancelled";

            _db.CustomerOrderStatusHistories.Add(
                new CustomerOrderStatusHistory
                {
                    OrderId = order.Id,
                    ChangedByUserId = userId,
                    FromStatus = "Confirmed",
                    ToStatus = "Cancelled",
                    Note = reason,
                    PaymentCollected = false,
                    CreatedAt = DateTime.UtcNow
                });

            await _db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }
        catch (Exception error) when (IsConflict(error))
        {
            await transaction.RollbackAsync(ct);

            throw new BadHttpRequestException(
                "The order or stock changed. Refresh the order and try again.",
                409);
        }
    }
}