using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public class SavePackageDto : IValidatableObject
{
    [Required, StringLength(150, MinimumLength = 2)]
    public string Name { get; set; } = string.Empty;

    [Required, StringLength(2000)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public string Category { get; set; } = string.Empty;

    [Range(0.01, 1_000_000)]
    public decimal BaseRate { get; set; }

    public decimal? MinimumCharge { get; set; }

    public string? CropType { get; set; }
    public decimal? QuantityPerAcreKg { get; set; }

    public decimal? MaxLoadKg { get; set; }
    public decimal? RatePerExtraKg { get; set; }

    public bool IsActive { get; set; } = true;

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        var validCategories = new[] { "MACHINERY", "INPUTS", "TRANSPORT" };

        if (!validCategories.Contains(Category))
        {
            yield return new ValidationResult(
                "Category must be MACHINERY, INPUTS or TRANSPORT.",
                [nameof(Category)]);
        }

        if (Category == "INPUTS")
        {
            if (string.IsNullOrWhiteSpace(CropType))
            {
                yield return new ValidationResult(
                    "Crop type is required for input packages.",
                    [nameof(CropType)]);
            }

            if (QuantityPerAcreKg is not > 0)
            {
                yield return new ValidationResult(
                    "Quantity per acre (kg) is required for input packages.",
                    [nameof(QuantityPerAcreKg)]);
            }
        }

        if (Category == "TRANSPORT" && MaxLoadKg is not > 0)
        {
            yield return new ValidationResult(
                "Max included load (kg) is required for transport packages.",
                [nameof(MaxLoadKg)]);
        }

        if (MinimumCharge is < 0)
        {
            yield return new ValidationResult(
                "Minimum charge cannot be negative.",
                [nameof(MinimumCharge)]);
        }
    }
}

public record PackageResponseDto(
    int Id,
    string Name,
    string Description,
    string Category,
    decimal BaseRate,
    decimal? MinimumCharge,
    string? CropType,
    decimal? QuantityPerAcreKg,
    decimal? MaxLoadKg,
    decimal? RatePerExtraKg,
    bool IsActive,
    int CreatedById,
    string CreatedByName,
    DateTime CreatedAt,
    DateTime? UpdatedAt,
    Guid Version
);

public class CreateBookingDto
{
    [Required]
    public int PackageId { get; set; }

    [Range(0.01, 100_000)]
    public decimal? LandSizeAcres { get; set; }

    [Range(0.01, 100_000)]
    public decimal? DistanceKm { get; set; }

    [Range(0, 1_000_000)]
    public decimal? LoadWeightKg { get; set; }

    [StringLength(500)]
    public string? Notes { get; set; }
}

public record QuoteResponseDto(
    int PackageId,
    string Category,
    decimal CalculatedQuantity,
    string QuantityUnit,
    decimal TotalPrice
);

public record BookingResponseDto(
    int Id,
    int PackageId,
    string PackageName,
    string Category,
    decimal? LandSizeAcres,
    decimal? DistanceKm,
    decimal? LoadWeightKg,
    decimal CalculatedQuantity,
    decimal TotalPrice,
    string Status,
    string? Notes,
    string? AdminNote,
    int FarmerId,
    string FarmerName,
    DateTime CreatedAt,
    Guid Version
);

public class ReviewBookingDto
{
    [Required]
    public Guid Version { get; set; }

    [StringLength(500)]
    public string? AdminNote { get; set; }
}
