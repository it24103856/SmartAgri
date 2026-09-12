using System.Data;
using System.Globalization;
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class CustomerCheckoutService
{
    private readonly ApplicationDbContext _db;
    private readonly IConfiguration _config;
    private readonly IDataProtector _protector;

    public CustomerCheckoutService(
        ApplicationDbContext db,
        IConfiguration config,
        IDataProtectionProvider protection)
    {
        _db = db;
        _config = config;
        _protector = protection.CreateProtector(
            "SmartAgri.PayHere.Checkout.v1");
    }

    private IQueryable<CustomerOrder> Orders =>
        _db.CustomerOrders
            .Include(o => o.Items)
            .Include(o => o.Payment);

    public async Task<int> CustomerId(ClaimsPrincipal user)
    {
        if (!int.TryParse(
                user.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            throw new UnauthorizedAccessException(
                "Please sign in again.");
        }

        var active = await _db.Users.AnyAsync(u =>
            u.Id == id &&
            u.Role == "CUSTOMER" &&
            u.Status == "ACTIVE");

        if (!active)
        {
            throw new UnauthorizedAccessException(
                "An active customer account is required.");
        }

        return id;
    }

    public async Task<CustomerOrder> Get(int userId, int orderId)
    {
        return await Orders.AsNoTracking()
            .SingleOrDefaultAsync(o =>
                o.Id == orderId && o.UserId == userId)
            ?? throw new BadHttpRequestException(
                "Order not found.", 404);
    }

    public Task<List<CustomerOrder>> List(int userId)
    {
        return Orders.AsNoTracking()
            .Where(o => o.UserId == userId)
            .OrderByDescending(o => o.Id)
            .Take(50)
            .ToListAsync();
    }

    private static string Sha256(string value) =>
        Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(value)));

    private static string Md5(string value) =>
        Convert.ToHexString(
            MD5.HashData(Encoding.UTF8.GetBytes(value)));

    private static bool Retryable(Exception error)
    {
        if (error is DbUpdateConcurrencyException)
            return true;

        if (error is PostgresException pg &&
            pg.SqlState is "40001" or "40P01" or "23505")
            return true;

        return error.InnerException is not null &&
               Retryable(error.InnerException);
    }

    private async Task<T> Transaction<T>(Func<Task<T>> action)
    {
        for (var attempt = 0; ; attempt++)
        {
            _db.ChangeTracker.Clear();

            await using var transaction =
                await _db.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable);

            try
            {
                var result = await action();

                await _db.SaveChangesAsync();
                await transaction.CommitAsync();

                return result;
            }
            catch (Exception error) when (Retryable(error))
            {
                await transaction.RollbackAsync();

                if (attempt >= 2)
                {
                    throw new BadHttpRequestException(
                        "Stock or cart changed. Please retry.", 409);
                }

                await Task.Delay(50 * (attempt + 1));
            }
        }
    }

    public Task<CustomerOrder> Create(
        int userId,
        CustomerCheckoutRequest request)
    {
        return Transaction(async () =>
        {
            if (request.RequestId == Guid.Empty)
            {
                throw new BadHttpRequestException(
                    "A request ID is required.");
            }

            var hash = Sha256(JsonSerializer.Serialize(request));

            var existing = await Orders.SingleOrDefaultAsync(o =>
                o.UserId == userId &&
                o.RequestId == request.RequestId);

            if (existing is not null)
            {
                if (existing.RequestHash != hash)
                {
                    throw new BadHttpRequestException(
                        "This request ID belongs to another checkout.",
                        409);
                }

                return existing;
            }

            if (request.PaymentMethod == "PAYHERE")
                PayHereSettings();

            var ids = request.Items
                .Select(i => i.ProductId)
                .ToArray();

            if (ids.Distinct().Count() != ids.Length)
            {
                throw new BadHttpRequestException(
                    "Duplicate product lines are not allowed.");
            }

            var products = await _db.Products
                .Where(p => ids.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id);

            var cartItems = new List<CartItem>();

            if (request.FromCart)
            {
                cartItems = await (
                    from item in _db.CartItems
                    join cart in _db.Carts
                        on item.CartId equals cart.Id
                    where cart.UserId == userId
                    select item
                ).ToListAsync();

                var matches =
                    cartItems.Count == request.Items.Count &&
                    request.Items.All(line => cartItems.Any(item =>
                        item.ProductId == line.ProductId &&
                        item.Quantity == line.Quantity));

                if (!matches)
                {
                    throw new BadHttpRequestException(
                        "Your cart changed. Review it again.", 409);
                }
            }

            var order = new CustomerOrder
            {
                UserId = userId,
                RequestId = request.RequestId,
                RequestHash = hash,
                FullName = request.FullName.Trim(),
                Email = request.Email.Trim(),
                Phone = request.Phone.Trim(),
                Address = request.Address.Trim(),
                City = request.City.Trim(),
                DeliveryFee = 0m
            };

            foreach (var line in request.Items)
            {
                if (!products.TryGetValue(line.ProductId, out var product) ||
                    product.Status != "APPROVED" ||
                    product.StockQuantity < line.Quantity ||
                    product.Price <= 0)
                {
                    throw new BadHttpRequestException(
                        "A product is unavailable or has insufficient stock.",
                        409);
                }

                if (product.Price != line.UnitPrice)
                {
                    throw new BadHttpRequestException(
                        $"{product.Name}: price changed. Review checkout again.",
                        409);
                }

                order.Items.Add(new CustomerOrderLine
                {
                    ProductId = product.Id,
                    Name = product.Name,
                    Unit = product.Unit,
                    Quantity = line.Quantity,
                    UnitPrice = product.Price,
                    SourceCartItemId = cartItems
                        .SingleOrDefault(i => i.ProductId == product.Id)?.Id
                });
            }

            order.Subtotal = order.Items.Sum(i => i.LineTotal);
            order.TotalAmount = order.Subtotal + order.DeliveryFee;

            order.Payment = new CustomerPayment
            {
                Method = request.PaymentMethod,
                Amount = order.TotalAmount,
                Status = request.PaymentMethod == "COD"
                    ? "Unpaid"
                    : "Pending"
            };

            if (request.PaymentMethod == "COD")
            {
                if (!await ConfirmStock(order))
                {
                    throw new BadHttpRequestException(
                        "Stock changed. Review checkout again.", 409);
                }

                order.Status = "Confirmed";
                await ClearPurchasedCartLines(order);
            }

            _db.CustomerOrders.Add(order);
            return order;
        });
    }

    private async Task<bool> ConfirmStock(CustomerOrder order)
    {
        var ids = order.Items.Select(i => i.ProductId).ToArray();

        var products = await _db.Products
            .Where(p => ids.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id);

        foreach (var line in order.Items)
        {
            if (!products.TryGetValue(line.ProductId, out var product) ||
                product.Status != "APPROVED" ||
                product.StockQuantity < line.Quantity)
            {
                return false;
            }
        }

        foreach (var line in order.Items)
        {
            var product = products[line.ProductId];

            product.StockQuantity -= line.Quantity;
            product.Version = Guid.NewGuid();
        }

        return true;
    }

    private async Task ClearPurchasedCartLines(CustomerOrder order)
    {
        var ids = order.Items
            .Where(i => i.SourceCartItemId.HasValue)
            .Select(i => i.SourceCartItemId!.Value)
            .ToArray();

        if (ids.Length == 0)
            return;

        var current = await (
            from item in _db.CartItems
            join cart in _db.Carts
                on item.CartId equals cart.Id
            where cart.UserId == order.UserId &&
                  ids.Contains(item.Id)
            select item
        ).ToListAsync();

        foreach (var item in current)
        {
            var purchased = order.Items.Single(i =>
                i.SourceCartItemId == item.Id);

            // Preserve lines that the customer changed during payment.
            if (item.ProductId == purchased.ProductId &&
                item.Quantity == purchased.Quantity)
            {
                _db.CartItems.Remove(item);
            }
        }
    }

    private (string BaseUrl, string Merchant, string Secret)
        PayHereSettings()
    {
        var baseUrl = _config["PayHere:PublicBaseUrl"]?.TrimEnd('/');
        var merchant = _config["PayHere:MerchantId"];
        var secret = _config["PayHere:MerchantSecret"];

        if (string.IsNullOrWhiteSpace(merchant) ||
            string.IsNullOrWhiteSpace(secret) ||
            !Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri) ||
            uri.Scheme != Uri.UriSchemeHttps ||
            uri.AbsolutePath != "/")
        {
            throw new BadHttpRequestException(
                "Online payment is not configured. Choose Cash on Delivery.",
                503);
        }

        return (baseUrl!, merchant, secret);
    }

    public async Task<string> PaymentUrl(int userId, int orderId)
    {
        var order = await Get(userId, orderId);

        if (order.Payment.Method != "PAYHERE" ||
            order.Payment.Status != "Pending")
        {
            throw new BadHttpRequestException(
                "This order is not awaiting an online payment.");
        }

        var settings = PayHereSettings();

        var expiry = DateTimeOffset.UtcNow
            .AddMinutes(15)
            .ToUnixTimeSeconds();

        var token = _protector.Protect($"{order.Id}|{expiry}");

        return settings.BaseUrl +
               "/api/customer-payments/checkout?token=" +
               Uri.EscapeDataString(token);
    }

    public async Task<string> CheckoutHtml(string token)
    {
        int orderId;

        try
        {
            var parts = _protector.Unprotect(token).Split('|');

            orderId = int.Parse(parts[0], CultureInfo.InvariantCulture);

            var expiry = long.Parse(
                parts[1], CultureInfo.InvariantCulture);

            if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() > expiry)
                throw new Exception();
        }
        catch
        {
            throw new BadHttpRequestException(
                "Payment link expired. Open payment again from the app.");
        }

        var order = await Orders.AsNoTracking()
            .SingleOrDefaultAsync(o => o.Id == orderId)
            ?? throw new BadHttpRequestException("Order not found.", 404);

        if (order.Payment.Method != "PAYHERE" ||
            order.Payment.Status != "Pending")
        {
            throw new BadHttpRequestException(
                "This payment is no longer pending.");
        }

        var settings = PayHereSettings();

        var amount = order.TotalAmount.ToString(
            "0.00", CultureInfo.InvariantCulture);

        var names = order.FullName.Split(
            ' ', 2, StringSplitOptions.RemoveEmptyEntries);

        var gatewayId = order.Payment.GatewayOrderId;

        var hash = Md5(
            settings.Merchant +
            gatewayId +
            amount +
            "LKR" +
            Md5(settings.Secret));

        var fields = new Dictionary<string, string>
        {
            ["merchant_id"] = settings.Merchant,
            ["return_url"] = settings.BaseUrl +
                             "/api/customer-payments/return",
            ["cancel_url"] = settings.BaseUrl +
                             "/api/customer-payments/return",
            ["notify_url"] = settings.BaseUrl +
                             "/api/customer-payments/notify",
            ["first_name"] = names[0],
            ["last_name"] = names.Length > 1 ? names[1] : "-",
            ["email"] = order.Email,
            ["phone"] = order.Phone,
            ["address"] = order.Address,
            ["city"] = order.City,
            ["country"] = "Sri Lanka",
            ["order_id"] = gatewayId,
            ["items"] = $"SmartAgri order #{order.Id}",
            ["currency"] = "LKR",
            ["amount"] = amount,
            ["hash"] = hash
        };

        var inputs = string.Join("", fields.Select(field =>
            "<input type=\"hidden\" name=\"" +
            WebUtility.HtmlEncode(field.Key) +
            "\" value=\"" +
            WebUtility.HtmlEncode(field.Value) +
            "\">"));

        return "<!doctype html><html><head>" +
               "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" +
               "<title>SmartAgri payment</title></head><body>" +
               "<h2>SmartAgri — Sandbox payment</h2>" +
               $"<p>Order #{order.Id} · LKR {amount}</p>" +
               "<form method=\"post\" action=\"https://sandbox.payhere.lk/pay/checkout\">" +
               inputs +
               "<button type=\"submit\">Continue to PayHere Sandbox</button>" +
               "</form></body></html>";
    }

    public async Task Notify(IFormCollection form)
    {
        var settings = PayHereSettings();

        string Field(string name) => form[name].ToString();

        var merchant = Field("merchant_id");
        var gatewayId = Field("order_id");
        var amountText = Field("payhere_amount");
        var currency = Field("payhere_currency");
        var status = Field("status_code");
        var paymentId = Field("payment_id");

        var expected = Md5(
            merchant +
            gatewayId +
            amountText +
            currency +
            status +
            Md5(settings.Secret));

        bool valid;

        try
        {
            valid = CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(expected),
                Convert.FromHexString(Field("md5sig")));
        }
        catch
        {
            valid = false;
        }

        if (!valid ||
            merchant != settings.Merchant ||
            currency != "LKR" ||
            !decimal.TryParse(
                amountText,
                NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture,
                out var amount))
        {
            throw new BadHttpRequestException(
                "Invalid payment notification.");
        }

        if (status is not ("2" or "0" or "-1" or "-2" or "-3"))
            throw new BadHttpRequestException("Unknown payment status.");

        if ((status == "2" || status == "-3") &&
            string.IsNullOrWhiteSpace(paymentId))
        {
            throw new BadHttpRequestException(
                "Payment reference is required.");
        }

        await Transaction(async () =>
        {
            var order = await Orders.SingleOrDefaultAsync(o =>
                o.Payment.GatewayOrderId == gatewayId)
                ?? throw new BadHttpRequestException(
                    "Order not found.", 404);

            var payment = order.Payment;

            if (payment.Method != "PAYHERE" ||
                amount != payment.Amount)
            {
                throw new BadHttpRequestException(
                    "Payment amount does not match the order.");
            }

            if (payment.Status == "Chargeback")
                return true;

            if (status == "-3")
            {
                payment.Status = "Chargeback";
                order.Status = "PaymentReview";
                order.ReviewReason =
                    "The payment provider reported a chargeback.";

                return true;
            }

            if (payment.Status == "Paid")
            {
                // Repeated notifications must not deduct stock twice.
                if (status == "2" &&
                    payment.ProviderPaymentId != paymentId)
                {
                    order.Status = "PaymentReview";
                    order.ReviewReason =
                        "Additional payment reference received: " +
                        paymentId;
                }

                return true;
            }

            if (status == "2")
            {
                payment.Status = "Paid";
                payment.ProviderPaymentId = paymentId;
                payment.PaidAt = DateTime.UtcNow;

                if (await ConfirmStock(order))
                {
                    order.Status = "Confirmed";
                    await ClearPurchasedCartLines(order);
                }
                else
                {
                    order.Status = "PaymentReview";
                    order.ReviewReason =
                        "Payment received, but stock is no longer available. " +
                        "Contact support for fulfillment or a refund.";
                }
            }
            else if (status is "-1" or "-2")
            {
                payment.Status = status == "-1"
                    ? "Cancelled"
                    : "Failed";

                order.Status = "PaymentFailed";
            }

            return true;
        });
    }
}