using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class SmartBasketDecisionRequest : IValidatableObject
{
    public Guid Version { get; set; }

    [Range(1, int.MaxValue)]
    public int ProposalRevision { get; set; }

    [Required]
    [RegularExpression("^(Approved|Rejected)$")]
    public string Decision { get; set; } = "";

    [StringLength(1000)]
    public string? Note { get; set; }

    public IEnumerable<ValidationResult> Validate(
        ValidationContext validationContext)
    {
        if (Version == Guid.Empty)
        {
            yield return new ValidationResult(
                "Version is required.",
                new[] { nameof(Version) });
        }

        if (Decision == "Rejected" &&
            string.IsNullOrWhiteSpace(Note))
        {
            yield return new ValidationResult(
                "Please provide a rejection reason.",
                new[] { nameof(Note) });
        }
    }
}