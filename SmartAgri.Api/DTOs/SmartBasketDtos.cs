using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class CreateSmartBasketRequest : IValidatableObject
{

    // null = all food categories; positive ID = one category.
    [Range(1, int.MaxValue)]
    public int? CategoryId { get; set; }
    public Guid RequestId { get; set; }

    [Required]
    [StringLength(1000, MinimumLength = 1)]
    public string Objective { get; set; } = "";

    [Range(typeof(decimal), "1", "1000000")]
    public decimal? Budget { get; set; }

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
            Objective.Trim().Length < 1)
        {
            yield return new ValidationResult(
                "Enter the products you want or describe your basket.",
                new[] { nameof(Objective) });
        }

        if (Budget is decimal budget && decimal.Round(budget, 2) != budget)
        {
            yield return new ValidationResult(
                "Budget can have at most two decimal places.",
                new[] { nameof(Budget) });
        }
    }
}