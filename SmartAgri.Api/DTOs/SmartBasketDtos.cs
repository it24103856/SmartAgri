using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class CreateSmartBasketRequest : IValidatableObject
{

    // null = all food categories; positive ID = one category.
    [Range(1, int.MaxValue)]
    public int? CategoryId { get; set; }
    public Guid RequestId { get; set; }

    [Required]
    [StringLength(1000, MinimumLength = 5)]
    public string Objective { get; set; } = "";

    [Range(typeof(decimal), "1", "1000000")]
    public decimal Budget { get; set; }

    public IEnumerable<ValidationResult> Validate(
        ValidationContext validationContext)
    {
        if (RequestId == Guid.Empty)
        {
            yield return new ValidationResult(
                "A request ID is required.",
                new[] { nameof(RequestId) });
        }

        if (string.IsNullOrWhiteSpace(Objective) ||
            Objective.Trim().Length < 5)
        {
            yield return new ValidationResult(
                "Describe what you want using at least 5 characters.",
                new[] { nameof(Objective) });
        }

        if (decimal.Round(Budget, 2) != Budget)
        {
            yield return new ValidationResult(
                "Budget can have at most two decimal places.",
                new[] { nameof(Budget) });
        }
    }
}