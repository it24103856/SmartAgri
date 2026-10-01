using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class PackagePaymentService
{
    private readonly ApplicationDbContext _db;
    private readonly IConfiguration _config;
    private readonly string _receiptRoot;

    public PackagePaymentService(
        ApplicationDbContext db,
        IConfiguration config,
        IWebHostEnvironment environment)
    {
        _db = db;
        _config = config;

        // Outside wwwroot and the public uploads directories.
        _receiptRoot = Path.GetFullPath(Path.Combine(
            environment.ContentRootPath,
            "..",
            "SmartAgri.Private",
            "package-receipts"));

        Directory.CreateDirectory(_receiptRoot);
    }

    private async Task<User> Actor(ClaimsPrincipal principal)
    {
        if (!int.TryParse(
                principal.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            throw new PackageOperationException(401, "Please sign in again.");
        }

        return await _db.Users.SingleOrDefaultAsync(u =>
            u.Id == id &&
            u.Status == "ACTIVE" &&
            (u.Role == "FARMER" || u.Role == "ADMIN"))
            ?? throw new PackageOperationException(
                403, "An active farmer or admin account is required.");
    }

    private async Task<PackageBooking> Booking(int id, User actor)
    {
        return await _db.PackageBookings
            .SingleOrDefaultAsync(b =>
                b.Id == id &&
                (actor.Role == "ADMIN" || b.FarmerId == actor.Id))
            ?? throw new PackageOperationException(404, "Booking not found.");
    }

    private static (string Stage, decimal Amount)? Due(PackageBooking b)
    {
        if (!b.RequiresAdvancePayment)
            return null;

        if (b.Status == "AWAITING_PAYMENT" &&
            b.PaymentStatus == "UNPAID" &&
            b.AmountPaid == 0)
        {
            return ("ADVANCE", b.AdvanceAmount);
        }

        if (b.Status == "COMPLETED" &&
            b.PaymentStatus == "PARTIALLY_PAID")
        {
            return ("BALANCE", b.TotalPrice - b.AmountPaid);
        }

        return null;
    }

    private string Setting(string name) =>
        _config[$"PackageBankTransfer:{name}"]?.Trim() ?? "";

    private bool BankConfigured() =>
        new[] { "BankName", "AccountName", "AccountNumber" }
            .All(name =>
                !string.IsNullOrWhiteSpace(Setting(name)) &&
                !Setting(name).Contains("YOUR_", StringComparison.Ordinal));

    private static object ProofView(PackagePaymentProof p) => new
    {
        p.Id,
        p.BookingId,
        p.Stage,
        p.Amount,
        p.TransferReference,
        p.Status,
        p.AdminNote,
        p.CreatedAt,
        p.ReviewedAt,
        p.Version,
        FarmerName = p.Booking?.Farmer?.FullName,
        PackageName = p.Booking?.Package?.Name
    };

    public async Task<object> Summary(
        ClaimsPrincipal principal, int bookingId)
    {
        var actor = await Actor(principal);
        var booking = await Booking(bookingId, actor);

        var proofs = await _db.PackagePaymentProofs
            .AsNoTracking()
            .Where(p => p.BookingId == bookingId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();

        var due = Due(booking);
        var stage = due?.Stage;

        var occupied = proofs.Any(p =>
            p.Stage == stage &&
            (p.Status == "SUBMITTED" || p.Status == "APPROVED"));

        return new
        {
            booking.Id,
            booking.Status,
            booking.RequiresAdvancePayment,
            booking.PaymentStatus,
            booking.TotalPrice,
            booking.AdvanceAmount,
            booking.AmountPaid,
            Outstanding = booking.TotalPrice - booking.AmountPaid,
            DueStage = stage,
            DueAmount = due?.Amount,
            CanSubmit = due.HasValue && !occupied && BankConfigured(),
            BankConfigured = BankConfigured(),
            Bank = new
            {
                BankName = Setting("BankName"),
                AccountName = Setting("AccountName"),
                AccountNumber = Setting("AccountNumber"),
                Branch = Setting("Branch")
            },
            Proofs = proofs.Select(ProofView).ToArray()
        };
    }

    private async Task<string> SaveReceipt(IFormFile file)
    {
        if (file.Length < 12 || file.Length > 5 * 1024 * 1024)
            throw new PackageOperationException(
                400, "Choose a valid receipt image up to 5 MB.");

        using var memory = new MemoryStream();
        await file.CopyToAsync(memory);
        var bytes = memory.ToArray();

        if (bytes.Length < 12 || bytes.Length > 5 * 1024 * 1024)
            throw new PackageOperationException(400, "Invalid receipt size.");

        string? extension = null;

        if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255)
            extension = ".jpg";
        else if (bytes.Take(8).SequenceEqual(
                     new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }))
            extension = ".png";
        else if (System.Text.Encoding.ASCII.GetString(bytes, 0, 4) == "RIFF" &&
                 System.Text.Encoding.ASCII.GetString(bytes, 8, 4) == "WEBP")
            extension = ".webp";

        if (extension is null)
            throw new PackageOperationException(
                400, "Only JPG, PNG and WebP receipts are supported.");

        var name = Guid.NewGuid().ToString("N") + extension;
        var path = Path.Combine(_receiptRoot, name);

        try
        {
            await File.WriteAllBytesAsync(path, bytes);
        }
        catch
        {
            TryDelete(name);
            throw;
        }

        return name;
    }

    private void TryDelete(string name)
    {
        try
        {
            File.Delete(Path.Combine(_receiptRoot, Path.GetFileName(name)));
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    public async Task<object> Submit(
        ClaimsPrincipal principal,
        int bookingId,
        SubmitPackageReceiptDto dto)
    {
        var actor = await Actor(principal);

        if (actor.Role != "FARMER")
            throw new PackageOperationException(403, "Farmer access required.");

        var booking = await Booking(bookingId, actor);
        var due = Due(booking)
            ?? throw new PackageOperationException(
                409, "This booking is not awaiting a payment receipt.");

        if (!BankConfigured())
            throw new PackageOperationException(
                503, "Bank details have not been configured.");

        if (due.Amount <= 0)
            throw new PackageOperationException(409, "Invalid payment amount.");

        var occupied = await _db.PackagePaymentProofs.AnyAsync(p =>
            p.BookingId == bookingId &&
            p.Stage == due.Stage &&
            (p.Status == "SUBMITTED" || p.Status == "APPROVED"));

        if (occupied)
            throw new PackageOperationException(
                409, "A receipt for this stage is already pending or approved.");

        var filename = await SaveReceipt(dto.Receipt);

        var proof = new PackagePaymentProof
        {
            BookingId = booking.Id,
            Booking = booking,
            Stage = due.Stage,
            Amount = due.Amount,
            TransferReference = dto.TransferReference.Trim(),
            ReceiptFileName = filename
        };

        // Concurrency token protects against simultaneous booking changes.
        booking.Version = Guid.NewGuid();
        booking.UpdatedAt = DateTime.UtcNow;

        _db.PackagePaymentProofs.Add(proof);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch
        {
            TryDelete(filename);
            throw;
        }

        return ProofView(proof);
    }

    public async Task<object> Pending(ClaimsPrincipal principal)
    {
        var actor = await Actor(principal);

        if (actor.Role != "ADMIN")
            throw new PackageOperationException(403, "Admin access required.");

        var proofs = await _db.PackagePaymentProofs
            .Include(p => p.Booking).ThenInclude(b => b.Farmer)
            .Include(p => p.Booking).ThenInclude(b => b.Package)
            .AsNoTracking()
            .Where(p => p.Status == "SUBMITTED")
            .OrderBy(p => p.CreatedAt)
            .Take(200)
            .ToListAsync();

        return proofs.Select(ProofView).ToArray();
    }

    public async Task<object> Review(
        ClaimsPrincipal principal,
        int proofId,
        ReviewPackageReceiptDto dto,
        bool approve)
    {
        var actor = await Actor(principal);

        if (actor.Role != "ADMIN")
            throw new PackageOperationException(403, "Admin access required.");

        var proof = await _db.PackagePaymentProofs
            .Include(p => p.Booking)
            .SingleOrDefaultAsync(p => p.Id == proofId)
            ?? throw new PackageOperationException(404, "Receipt not found.");

        if (dto.Version == Guid.Empty ||
            proof.Version != dto.Version ||
            proof.Status != "SUBMITTED")
        {
            throw new PackageOperationException(
                409, "This receipt changed. Refresh and try again.");
        }

        var booking = proof.Booking;
        var note = dto.AdminNote?.Trim();

        if (approve)
        {
            if (!dto.CreditVerified)
                throw new PackageOperationException(
                    400, "Confirm that the bank credit was verified.");

            var due = Due(booking)
                ?? throw new PackageOperationException(
                    409, "This booking is no longer awaiting this payment.");

            if (proof.Stage != due.Stage || proof.Amount != due.Amount)
                throw new PackageOperationException(
                    409, "Receipt amount or stage does not match the booking.");

            booking.AmountPaid += proof.Amount;

            if (proof.Stage == "ADVANCE")
            {
                booking.PaymentStatus = "PARTIALLY_PAID";
                booking.Status = "CONFIRMED";
            }
            else
            {
                booking.PaymentStatus = "PAID";
                // Service status remains COMPLETED.
            }

            proof.Status = "APPROVED";
        }
        else
        {
            if (string.IsNullOrWhiteSpace(note) || note.Length < 3)
                throw new PackageOperationException(
                    400, "Enter a reason for rejecting this receipt.");

            proof.Status = "REJECTED";
        }

        proof.AdminNote = note;
        proof.ReviewedById = actor.Id;
        proof.ReviewedAt = DateTime.UtcNow;
        proof.Version = Guid.NewGuid();

        booking.UpdatedAt = DateTime.UtcNow;
        booking.Version = Guid.NewGuid();

        // Receipt approval and booking payment changes commit together.
        await _db.SaveChangesAsync();

        return ProofView(proof);
    }

    public async Task<(byte[] Bytes, string ContentType)> Receipt(
        ClaimsPrincipal principal, int proofId)
    {
        var actor = await Actor(principal);

        var proof = await _db.PackagePaymentProofs
            .Include(p => p.Booking)
            .AsNoTracking()
            .SingleOrDefaultAsync(p =>
                p.Id == proofId &&
                (actor.Role == "ADMIN" ||
                 p.Booking.FarmerId == actor.Id))
            ?? throw new PackageOperationException(404, "Receipt not found.");

        var name = Path.GetFileName(proof.ReceiptFileName);
        var path = Path.Combine(_receiptRoot, name);

        if (!File.Exists(path))
            throw new PackageOperationException(404, "Receipt file not found.");

        var type = Path.GetExtension(name) switch
        {
            ".jpg" => "image/jpeg",
            ".png" => "image/png",
            ".webp" => "image/webp",
            _ => throw new PackageOperationException(400, "Invalid receipt.")
        };

        return (await File.ReadAllBytesAsync(path), type);
    }
}