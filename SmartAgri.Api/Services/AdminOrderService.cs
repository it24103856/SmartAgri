using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class AdminOrderService
{
    private readonly ApplicationDbContext _db;

    public AdminOrderService(ApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<int> RequireAdmin(
        ClaimsPrincipal principal,
        CancellationToken ct)
    {
        if (!int.TryParse(
                principal.FindFirstValue(ClaimTypes.NameIdentifier),
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Please sign in again.");
        }

        var allowed = await _db.Users.AnyAsync(
            user => user.Id == userId
                && user.Role == "ADMIN"
                && user.Status == "ACTIVE",
            ct);

        if (!allowed)
        {
            throw new UnauthorizedAccessException(
                "An active admin account is required.");
        }

        return userId;
    }

    public async Task<object> List(
        AdminOrderQuery request,
        CancellationToken ct)
    {
        var query = _db.CustomerOrders.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(request.Status))
        {
            query = query.Where(
                order => order.Status == request.Status);
        }

        var search = request.Search?.Trim();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.ToLowerInvariant();

            if (int.TryParse(search.TrimStart('#'), out var orderId))
            {
                query = query.Where(order =>
                    order.Id == orderId
                    || order.FullName.ToLower().Contains(term)
                    || order.Phone.Contains(search));
            }
            else
            {
                query = query.Where(order =>
                    order.FullName.ToLower().Contains(term)
                    || order.Email.ToLower().Contains(term)
                    || order.Phone.Contains(search));
            }
        }

        var totalCount = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(order => order.CreatedAt)
            .ThenByDescending(order => order.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(order => new
            {
                order.Id,
                order.FullName,
                order.Phone,
                order.City,
                order.Status,
                order.TotalAmount,
                order.Currency,
                order.CreatedAt,
                ItemCount = order.Items.Sum(item => item.Quantity),
                PaymentMethod = order.Payment.Method,
                PaymentStatus = order.Payment.Status
            })
            .ToListAsync(ct);

        return new
        {
            items,
            totalCount,
            page = request.Page,
            pageSize = request.PageSize,
            totalPages = (int)Math.Ceiling(
                totalCount / (double)request.PageSize)
        };
    }

    public async Task<CustomerOrder> Get(
        int orderId,
        CancellationToken ct)
    {
        return await _db.CustomerOrders
            .AsNoTracking()
            .Include(order => order.Items)
            .Include(order => order.Payment)
            .SingleOrDefaultAsync(order => order.Id == orderId, ct)
            ?? throw new BadHttpRequestException(
                "Order not found.", 404);
    }

    public async Task<object> History(
        int orderId,
        CancellationToken ct)
    {
        var exists = await _db.CustomerOrders.AnyAsync(
            order => order.Id == orderId,
            ct);

        if (!exists)
        {
            throw new BadHttpRequestException(
                "Order not found.", 404);
        }

        return await (
            from history in _db.CustomerOrderStatusHistories.AsNoTracking()
            join user in _db.Users
                on history.ChangedByUserId equals user.Id
            where history.OrderId == orderId
            orderby history.CreatedAt, history.Id
            select new
            {
                history.Id,
                history.OrderId,
                history.FromStatus,
                history.ToStatus,
                history.Note,
                history.PaymentCollected,
                history.CreatedAt,
                history.ChangedByUserId,
                ChangedByName = user.FullName
            }
        ).ToListAsync(ct);
    }

    private static string? NextStatus(string current)
    {
        return current switch
        {
            "Confirmed" => "Preparing",
            "Preparing" => "Packed",
            "Packed" => "Dispatched",
            "Dispatched" => "Delivered",
            _ => null
        };
    }

    private static bool IsConcurrencyConflict(Exception error)
    {
        if (error is DbUpdateConcurrencyException)
        {
            return true;
        }

        if (error is PostgresException postgres
            && postgres.SqlState is "40001" or "40P01")
        {
            return true;
        }

        return error.InnerException is not null
            && IsConcurrencyConflict(error.InnerException);
    }

    public async Task<CustomerOrder> UpdateStatus(
        int adminId,
        int orderId,
        UpdateAdminOrderStatusRequest request,
        CancellationToken ct)
    {
        await using var transaction =
            await _db.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                ct);

        try
        {
            var order = await _db.CustomerOrders
                .Include(value => value.Payment)
                .SingleOrDefaultAsync(
                    value => value.Id == orderId,
                    ct)
                ?? throw new BadHttpRequestException(
                    "Order not found.", 404);

            if (order.Status != request.ExpectedStatus)
            {
                throw new BadHttpRequestException(
                    "This order changed. Refresh it before updating.",
                    409);
            }

            var next = NextStatus(order.Status);

            if (next is null || request.Status != next)
            {
                throw new BadHttpRequestException(
                    $"Cannot change {order.Status} to {request.Status}.",
                    409);
            }

            var payment = order.Payment;

            if (payment.Method == "PAYHERE")
            {
                if (payment.Status != "Paid")
                {
                    throw new BadHttpRequestException(
                        "Online payment must be verified before processing.",
                        409);
                }

                if (request.PaymentCollected)
                {
                    throw new BadHttpRequestException(
                        "PaymentCollected is only used for Cash on Delivery.");
                }
            }
            else if (payment.Method == "COD")
            {
                if (payment.Status is not ("Unpaid" or "Paid"))
                {
                    throw new BadHttpRequestException(
                        "This payment needs review before processing.",
                        409);
                }

                if (request.PaymentCollected
                    && request.Status != "Delivered")
                {
                    throw new BadHttpRequestException(
                        "Confirm cash collection when marking delivery.");
                }

                if (request.Status == "Delivered"
                    && payment.Status == "Unpaid"
                    && !request.PaymentCollected)
                {
                    throw new BadHttpRequestException(
                        "Confirm cash was collected before marking delivery.",
                        409);
                }
            }
            else
            {
                throw new BadHttpRequestException(
                    "Unsupported payment method.",
                    409);
            }

            var previousStatus = order.Status;
            var now = DateTime.UtcNow;
            var collectedNow = false;

            if (payment.Method == "COD"
                && payment.Status == "Unpaid"
                && request.Status == "Delivered"
                && request.PaymentCollected)
            {
                payment.Status = "Paid";
                payment.PaidAt = now;
                collectedNow = true;
            }

            order.Status = request.Status;

            var note = request.Note?.Trim();

            _db.CustomerOrderStatusHistories.Add(
                new CustomerOrderStatusHistory
                {
                    OrderId = order.Id,
                    ChangedByUserId = adminId,
                    FromStatus = previousStatus,
                    ToStatus = order.Status,
                    Note = string.IsNullOrWhiteSpace(note) ? null : note,
                    PaymentCollected = collectedNow,
                    CreatedAt = now
                });

            await _db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }
        catch (Exception error) when (IsConcurrencyConflict(error))
        {
            await transaction.RollbackAsync(ct);

            throw new BadHttpRequestException(
                "Another update happened. Refresh the order and try again.",
                409);
        }

        return await Get(orderId, ct);
    }
}