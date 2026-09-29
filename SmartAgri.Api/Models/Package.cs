namespace SmartAgri.Api.Models;

public class Package
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;

    // MACHINERY | INPUTS | TRANSPORT
    public string Category { get; set; } = string.Empty;

    // Price per unit — acres for MACHINERY/INPUTS, km for TRANSPORT.
    public decimal BaseRate { get; set; }

    // Floor price for a booking, regardless of how small the calculated total is.
    public decimal? MinimumCharge { get; set; }

    // INPUTS only.
    public string? CropType { get; set; }
    public decimal? QuantityPerAcreKg { get; set; }

    // TRANSPORT only. Load included in BaseRate; extra load is billed at
    // RatePerExtraKg.
    public decimal? MaxLoadKg { get; set; }
    public decimal? RatePerExtraKg { get; set; }

    // Hidden from farmers without deleting booking history that references it.
    public string ImageUrlsJson { get; set; } = "[]";

    public bool IsActive { get; set; } = true;

    public int CreatedById { get; set; }
    public User? CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    public Guid Version { get; set; } = Guid.NewGuid();
}
