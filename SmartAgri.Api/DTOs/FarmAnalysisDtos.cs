using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace SmartAgri.Api.DTOs;

public sealed class CreateFarmAnalysisDto : IValidatableObject
{
    public Guid RequestId { get; set; }

    [Range(1, int.MaxValue)]
    public int FarmId { get; set; }

    [Required]
    [StringLength(500, MinimumLength = 3)]
    public string Objective { get; set; } = string.Empty;

    [Range(1, 12)]
    public int PlantingMonth { get; set; }

    public bool? WellDrained { get; set; }

    [Range(typeof(decimal), "-10", "60")]
    public decimal? TemperatureC { get; set; }

    [Range(typeof(decimal), "0", "14")]
    public decimal? SoilPh { get; set; }

    [Range(typeof(decimal), "0", "9000")]
    public decimal? ElevationM { get; set; }

    public bool? UpcountryWetZone { get; set; }

    [Range(typeof(decimal), "0", "3000")]
    public decimal? RainfallMmMonth { get; set; }

    [Range(typeof(decimal), "0", "100")]
    public decimal? HumidityPercent { get; set; }

    [Required]
    [MaxLength(3)]
    public string[] ExcludedCropIds { get; set; } =
        Array.Empty<string>();

    public IEnumerable<ValidationResult> Validate(
        ValidationContext validationContext)
    {
        if (RequestId == Guid.Empty)
        {
            yield return new ValidationResult(
                "RequestId must be a non-empty UUID.",
                new[] { nameof(RequestId) });
        }

        if (string.IsNullOrWhiteSpace(Objective) ||
            Objective.Trim().Length < 3)
        {
            yield return new ValidationResult(
                "Enter an objective with at least three characters.",
                new[] { nameof(Objective) });
        }

        var allowed = new HashSet<string>(StringComparer.Ordinal)
        {
            "chilli", "okra", "brinjal"
        };

        if (ExcludedCropIds is not null &&
            (ExcludedCropIds.Any(id =>
                id is null || !allowed.Contains(id)) ||
             ExcludedCropIds.Distinct().Count() !=
                ExcludedCropIds.Length))
        {
            yield return new ValidationResult(
                "Use unique crop IDs: chilli, okra, brinjal.",
                new[] { nameof(ExcludedCropIds) });
        }
    }
}

public sealed record FarmAnalysisResponseDto(
    Guid Id,
    Guid RequestId,
    int FarmId,
    string FarmName,
    string Objective,
    string Status,
    string? ErrorCode,
    DateTime CreatedAt,
    DateTime? CompletedAt,
    JsonElement Input,
    JsonElement? Result);

public sealed record FarmAnalysisSummaryDto(
    Guid Id,
    int FarmId,
    string FarmName,
    string Objective,
    string Status,
    string? ErrorCode,
    DateTime CreatedAt,
    DateTime? CompletedAt);