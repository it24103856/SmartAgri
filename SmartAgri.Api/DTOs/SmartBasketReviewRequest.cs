using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class SmartBasketReviewRequest : IValidatableObject
{
    public Guid Version { get; set; }

    [Required, MinLength(1), MaxLength(50)]
    public List<SmartBasketReviewLine> Items { get; set; } = new();

    public bool SubmitForApproval { get; set; }

    public IEnumerable<ValidationResult> Validate(
        ValidationContext validationContext)
    {
        if (Version == Guid.Empty)
        {
            yield return new ValidationResult(
                "Version is required.",
                new[] { nameof(Version) });
        }

        if (Items is null)
            yield break;

        if (Items.Any(item => item is null))
        {
            yield return new ValidationResult(
                "Items cannot contain null entries.",
                new[] { nameof(Items) });
            yield break;
        }

        if (Items.Select(item => item.ProductId).Distinct().Count()
            != Items.Count)
        {
            yield return new ValidationResult(
                "Duplicate products are not allowed.",
                new[] { nameof(Items) });
        }
    }
}

public sealed class SmartBasketReviewLine
{
    [Range(1, int.MaxValue)]
    public int ProductId { get; set; }

    [Range(1, 100000)]
    public int Quantity { get; set; }
}