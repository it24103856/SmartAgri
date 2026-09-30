namespace SmartAgri.Api.Models;

public class PackageBooking
{
    public int? FarmId { get; set; }
public Farm? Farm { get; set; }

// Preserve the original farm details in booking history.
public string? FarmName { get; set; }
public string? FarmLocation { get; set; }

public DateOnly? ServiceDate { get; set; }
    public int Id { get; set; }

    public int PackageId { get; set; }
    public Package? Package { get; set; }

    public int FarmerId { get; set; }
    public User? Farmer { get; set; }

    // Whichever of these the package's category needs — see PricingService.
    public decimal? LandSizeAcres { get; set; }
    public decimal? DistanceKm { get; set; }
    public decimal? LoadWeightKg { get; set; }

    // Server-calculated, never trusted from the client.
    public decimal CalculatedQuantity { get; set; }
    public decimal TotalPrice { get; set; }

    public string Status { get; set; } = "PENDING";
    // PENDING | CONFIRMED | REJECTED | CANCELLED | COMPLETED    
    public string? Notes { get; set; }
    public string? AdminNote { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    public Guid Version { get; set; } = Guid.NewGuid();
}
