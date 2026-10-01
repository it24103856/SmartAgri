namespace SmartAgri.Api.Models;

public sealed class PackagePaymentProof
{
    public int Id { get; set; }

    public int BookingId { get; set; }
    public PackageBooking Booking { get; set; } = null!;

    // ADVANCE or BALANCE
    public string Stage { get; set; } = "";

    // Always calculated by the server.
    public decimal Amount { get; set; }

    public string TransferReference { get; set; } = "";

    // Private server filename, never a public upload URL.
    public string ReceiptFileName { get; set; } = "";

    // SUBMITTED, APPROVED, REJECTED
    public string Status { get; set; } = "SUBMITTED";

    public string? AdminNote { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReviewedAt { get; set; }

    public int? ReviewedById { get; set; }
    public User? ReviewedBy { get; set; }

    public Guid Version { get; set; } = Guid.NewGuid();
}