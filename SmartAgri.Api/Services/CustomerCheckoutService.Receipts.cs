using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed partial class CustomerCheckoutService
{
    private string BankSetting(string key) =>
        (_config[$"OrderBankTransfer:{key}"] ?? _config[$"PackageBankTransfer:{key}"] ?? "").Trim();
    private bool OrderBankConfigured() => new[] { "BankName", "AccountName", "AccountNumber" }
        .All(key => BankSetting(key).Length > 0 && !BankSetting(key).Contains("YOUR_", StringComparison.Ordinal));

    private async Task<int> ReceiptActor(ClaimsPrincipal principal, bool admin)
    {
        if (!int.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ||
            !await _db.Users.AnyAsync(u => u.Id == id && u.Status == "ACTIVE" &&
                (admin ? u.Role == "ADMIN" : u.Role == "FARMER" || u.Role == "CUSTOMER")))
            throw new BadHttpRequestException("Account access denied.", 403);
        return id;
    }

    public async Task<object> OrderBankDetails(ClaimsPrincipal principal)
    {
        await ReceiptActor(principal, false);
        return new {
            bankConfigured = OrderBankConfigured(),
            bank = new { bankName = BankSetting("BankName"), accountName = BankSetting("AccountName"),
                accountNumber = BankSetting("AccountNumber"), branch = BankSetting("Branch") }
        };
    }

    public async Task<object> OrderPaymentSummary(ClaimsPrincipal principal, int id)
    {
        var userId = await ReceiptActor(principal, false);
        var order = await Get(userId, id);
        if (order.Payment.Method != "BANK_TRANSFER") throw new BadHttpRequestException("Not a bank transfer order.", 409);
        var proofs = await _db.OrderPaymentProofs.AsNoTracking().Where(p => p.OrderId == id)
            .OrderByDescending(p => p.CreatedAt).Select(p => new {
                p.Id, p.Amount, p.Status, p.TransferReference, p.AdminNote, p.Version, stage = "ORDER"
            }).ToListAsync();
        var due = order.Status == "AwaitingPayment" && order.Payment.Status != "Paid";
        return new {
            order.Status, paymentStatus = order.Payment.Status,
            amountPaid = order.Payment.Status == "Paid" ? order.TotalAmount : 0m,
            outstanding = order.Payment.Status == "Paid" ? 0m : order.TotalAmount,
            dueStage = due ? "ORDER" : null, dueAmount = due ? order.TotalAmount : 0m,
            canSubmit = due && OrderBankConfigured() && !proofs.Any(p => p.Status is "SUBMITTED" or "APPROVED"),
            bankConfigured = OrderBankConfigured(),
            bank = new { bankName = BankSetting("BankName"), accountName = BankSetting("AccountName"),
                accountNumber = BankSetting("AccountNumber"), branch = BankSetting("Branch") }, proofs
        };
    }

    public async Task SubmitOrderReceipt(ClaimsPrincipal principal, int id, SubmitPackageReceiptDto dto)
    {
        var userId = await ReceiptActor(principal, false);
        var order = await Get(userId, id);
        if (order.Payment.Method != "BANK_TRANSFER" || order.Status != "AwaitingPayment" || order.Payment.Status == "Paid")
            throw new BadHttpRequestException("This order is not awaiting a receipt.", 409);
        if (!OrderBankConfigured()) throw new BadHttpRequestException("Bank details are not configured.", 503);
        if (string.IsNullOrWhiteSpace(dto.TransferReference) || dto.TransferReference.Trim().Length > 100)
            throw new BadHttpRequestException("Enter a valid transfer reference.");
        var file = dto.Receipt;
        if (file == null || file.Length < 12 || file.Length > 5 * 1024 * 1024)
            throw new BadHttpRequestException("Choose a receipt image up to 5 MB.");
        using var stream = new MemoryStream();
        await file.CopyToAsync(stream);
        var bytes = stream.ToArray();
        if (bytes.Length < 12 || bytes.Length > 5 * 1024 * 1024) throw new BadHttpRequestException("Invalid receipt size.");
        var type = bytes.Take(8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10}) ? "image/png"
            : bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255 ? "image/jpeg"
            : System.Text.Encoding.ASCII.GetString(bytes, 0, 4) == "RIFF" && System.Text.Encoding.ASCII.GetString(bytes, 8, 4) == "WEBP" ? "image/webp" : null;
        if (type == null) throw new BadHttpRequestException("Use a JPG, PNG or WebP receipt.");
        _db.OrderPaymentProofs.Add(new() { OrderId = id, Amount = order.TotalAmount,
            TransferReference = dto.TransferReference.Trim(), Receipt = bytes, ContentType = type });
        await _db.SaveChangesAsync();
    }

    public async Task<object> PendingOrderReceipts(ClaimsPrincipal principal)
    {
        await ReceiptActor(principal, true);
        return await _db.OrderPaymentProofs.AsNoTracking().Where(p => p.Status == "SUBMITTED")
            .OrderBy(p => p.CreatedAt).Take(200).Select(p => new {
                p.Id, p.OrderId, p.Amount, p.TransferReference, p.Version,
                customerName = p.Order.FullName, stage = "ORDER"
            }).ToListAsync();
    }

    public async Task<(byte[] Bytes, string Type)> OrderReceipt(ClaimsPrincipal principal, int id)
    {
        var admin = principal.IsInRole("ADMIN");
        var actor = await ReceiptActor(principal, admin);
        var proof = await _db.OrderPaymentProofs.AsNoTracking()
            .Where(p => p.Id == id && (admin || p.Order.UserId == actor))
            .Select(p => new { p.Receipt, p.ContentType }).SingleOrDefaultAsync()
            ?? throw new BadHttpRequestException("Receipt not found.", 404);
        return (proof.Receipt, proof.ContentType);
    }

    public async Task ReviewOrderReceipt(ClaimsPrincipal principal, int id, ReviewPackageReceiptDto dto, bool approve)
    {
        var admin = await ReceiptActor(principal, true);
        if (approve && !dto.CreditVerified) throw new BadHttpRequestException("Verify the bank credit first.");
        if (!approve && (dto.AdminNote?.Trim().Length ?? 0) < 3) throw new BadHttpRequestException("A rejection reason is required.");
        await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var proof = await _db.OrderPaymentProofs.Include(p => p.Order).ThenInclude(o => o.Items)
            .Include(p => p.Order).ThenInclude(o => o.Payment).SingleOrDefaultAsync(p => p.Id == id)
            ?? throw new BadHttpRequestException("Receipt not found.", 404);
        if (proof.Version != dto.Version || proof.Status != "SUBMITTED" || proof.Order.Status != "AwaitingPayment")
            throw new BadHttpRequestException("Order or receipt changed. Refresh and try again.", 409);
        var order = proof.Order;
        if (order.Payment.Method != "BANK_TRANSFER" || order.Payment.Status == "Paid" || proof.Amount != order.TotalAmount)
            throw new BadHttpRequestException("Payment changed. Refresh and try again.", 409);
        if (approve) {
            // Stock is deducted only once, when the bank payment is approved.
            // A paid order without stock is retained for admin resolution.
            var stocked = await ConfirmStock(order);
            order.Status = stocked ? "Confirmed" : "PaymentReview";
            order.ReviewReason = stocked ? null : "Bank payment verified but stock is unavailable. Contact the buyer to resolve or refund.";
            order.Payment.Status = "Paid";
            order.Payment.PaidAt = DateTime.UtcNow;
            order.Payment.ProviderPaymentId = proof.TransferReference;
            await ClearPurchasedCartLines(order);
            _db.CustomerOrderStatusHistories.Add(new() { OrderId = order.Id, ChangedByUserId = admin,
                FromStatus = "AwaitingPayment", ToStatus = order.Status, Note = "Bank transfer verified.", PaymentCollected = true });
        }
        proof.Status = approve ? "APPROVED" : "REJECTED";
        proof.AdminNote = dto.AdminNote?.Trim();
        proof.ReviewedAt = DateTime.UtcNow;
        proof.ReviewedById = admin;
        proof.Version = Guid.NewGuid();
        await _db.SaveChangesAsync();
        await transaction.CommitAsync();
    }
}
