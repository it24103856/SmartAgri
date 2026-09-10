using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/cart")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class CartController : ControllerBase
{
    private readonly ApplicationDbContext _db;

    public CartController(ApplicationDbContext db)
    {
        _db = db;
    }

    private async Task<int?> CustomerId(
        CancellationToken ct)
    {
        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            return null;
        }

        var allowed = await _db.Users.AnyAsync(
            u => u.Id == id
                 && u.Role == "CUSTOMER"
                 && u.Status == "ACTIVE",
            ct);

        return allowed ? id : null;
    }

    // Read current product prices from the database.
    private async Task<List<CartLine>> Lines(
        int userId,
        CancellationToken ct)
    {
        return await (
            from item in _db.CartItems.AsNoTracking()
            join cart in _db.Carts
                on item.CartId equals cart.Id
            join product in _db.Products
                on item.ProductId equals product.Id
            where cart.UserId == userId
            orderby item.Id
            select new CartLine
            {
                ProductId = product.Id,
                Name = product.Name,
                Unit = product.Unit,

                ImageUrl = product.ImageUrls.Count > 0
                    ? product.ImageUrls[0]
                    : product.ImageUrl,

                Quantity = item.Quantity,
                UnitPrice = product.Price,
                StockQuantity = product.StockQuantity,

                Available = product.Status == "APPROVED"
                    && item.Quantity <= product.StockQuantity
            }
        ).ToListAsync(ct);
    }

    private static object Summary(
        List<CartLine> lines)
    {
        return new
        {
            items = lines,

            subtotal = lines.Sum(
                i => i.UnitPrice * i.Quantity),

            canCheckout = lines.Count > 0
                && lines.All(i => i.Available)
        };
    }

    // GET /api/cart
    [HttpGet]
    public async Task<IActionResult> GetCart(
        CancellationToken ct)
    {
        var userId = await CustomerId(ct);

        if (userId is null)
            return Forbid();

        var lines = await Lines(userId.Value, ct);

        return Ok(Summary(lines));
    }

    // POST /api/cart/items
    [HttpPost("items")]
    public Task<IActionResult> AddItem(
        CartItemRequest request,
        CancellationToken ct)
    {
        return Change(
            request.ProductId,
            request.Quantity,
            "add",
            ct);
    }

    // PUT /api/cart/items/5
    [HttpPut("items/{productId:int}")]
    public Task<IActionResult> SetQuantity(
        int productId,
        CartQuantityRequest request,
        CancellationToken ct)
    {
        return Change(
            productId,
            request.Quantity,
            "set",
            ct);
    }

    // DELETE /api/cart/items/5
    [HttpDelete("items/{productId:int}")]
    public Task<IActionResult> RemoveItem(
        int productId,
        CancellationToken ct)
    {
        return Change(
            productId,
            0,
            "remove",
            ct);
    }

    private async Task<IActionResult> Change(
        int productId,
        int quantity,
        string operation,
        CancellationToken ct)
    {
        var userId = await CustomerId(ct);

        if (userId is null)
            return Forbid();

        await using var transaction =
            await _db.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                ct);

        try
        {
            var cart = await _db.Carts.SingleOrDefaultAsync(
                c => c.UserId == userId.Value,
                ct);

            if (cart is null)
            {
                if (operation == "remove")
                    return NoContent();

                if (operation == "set")
                {
                    return NotFound(new
                    {
                        message = "Item not in cart."
                    });
                }

                cart = new Cart
                {
                    UserId = userId.Value
                };

                _db.Carts.Add(cart);
                await _db.SaveChangesAsync(ct);
            }

            var item =
                await _db.CartItems.SingleOrDefaultAsync(
                    i => i.CartId == cart.Id
                         && i.ProductId == productId,
                    ct);

            if (operation == "remove")
            {
                if (item is not null)
                    _db.CartItems.Remove(item);
            }
            else
            {
                if (operation == "set" && item is null)
                {
                    return NotFound(new
                    {
                        message = "Item not in cart."
                    });
                }

                var product = await _db.Products
                    .AsNoTracking()
                    .SingleOrDefaultAsync(
                        p => p.Id == productId
                             && p.Status == "APPROVED",
                        ct);

                if (product is null)
                {
                    return NotFound(new
                    {
                        message =
                            "This product is no longer available."
                    });
                }

                long desiredQuantity = operation == "add"
                    ? (long)(item?.Quantity ?? 0) + quantity
                    : quantity;

                if (desiredQuantity < 1
                    || desiredQuantity > product.StockQuantity
                    || desiredQuantity > int.MaxValue)
                {
                    return Conflict(new
                    {
                        message =
                            "Not enough stock for that quantity. "
                            + "Refresh and try again."
                    });
                }

                if (item is null)
                {
                    item = new CartItem
                    {
                        CartId = cart.Id,
                        ProductId = productId
                    };

                    _db.CartItems.Add(item);
                }

                item.Quantity = (int)desiredQuantity;
                item.UnitPrice = product.Price;
            }

            cart.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);

            return NoContent();
        }
        catch (Exception error) when (IsConflict(error))
        {
            return Conflict(new
            {
                message =
                    "The cart or product changed. "
                    + "Refresh and try again."
            });
        }
    }

    private static bool IsConflict(Exception error)
    {
        var postgresError =
            error as PostgresException
            ?? error.InnerException as PostgresException;

        return postgresError?.SqlState
            is "40001"
            or "40P01"
            or "23505"
            or "23503";
    }

    // Review the saved cart without placing an order.
    // GET /api/cart/checkout-preview
    [HttpGet("checkout-preview")]
    public async Task<IActionResult> PreviewCart(
        CancellationToken ct)
    {
        var userId = await CustomerId(ct);

        if (userId is null)
            return Forbid();

        var lines = await Lines(userId.Value, ct);

        if (lines.Count == 0)
        {
            return BadRequest(new
            {
                message = "Your cart is empty."
            });
        }

        if (lines.Any(i => !i.Available))
        {
            return Conflict(new
            {
                message =
                    "Some items are unavailable. "
                    + "Update your cart first."
            });
        }

        return Ok(Summary(lines));
    }

    // Review one product without changing the saved cart.
    // POST /api/cart/buy-now-preview
    [HttpPost("buy-now-preview")]
    public async Task<IActionResult> PreviewBuyNow(
        CartItemRequest request,
        CancellationToken ct)
    {
        if (await CustomerId(ct) is null)
            return Forbid();

        var product = await _db.Products
            .AsNoTracking()
            .SingleOrDefaultAsync(
                p => p.Id == request.ProductId
                     && p.Status == "APPROVED",
                ct);

        if (product is null)
        {
            return NotFound(new
            {
                message =
                    "This product is no longer available."
            });
        }

        if (request.Quantity > product.StockQuantity)
        {
            return Conflict(new
            {
                message =
                    "Not enough stock. "
                    + "Choose a smaller quantity."
            });
        }

        var lines = new List<CartLine>
        {
            new()
            {
                ProductId = product.Id,
                Name = product.Name,
                Unit = product.Unit,

                ImageUrl = product.ImageUrls.FirstOrDefault()
                    ?? product.ImageUrl,

                Quantity = request.Quantity,
                UnitPrice = product.Price,
                StockQuantity = product.StockQuantity,
                Available = true
            }
        };

        return Ok(Summary(lines));
    }
}

public sealed class CartLine
{
    public int ProductId { get; set; }

    public string Name { get; set; } = "";
    public string Unit { get; set; } = "";

    public string? ImageUrl { get; set; }

    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }

    public decimal LineTotal => UnitPrice * Quantity;

    public int StockQuantity { get; set; }
    public bool Available { get; set; }
}