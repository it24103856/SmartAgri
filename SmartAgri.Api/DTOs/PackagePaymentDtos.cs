using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class SubmitPackageReceiptDto
{
    [Required, StringLength(100)]
    public string TransferReference { get; set; } = "";

    [Required]
    public IFormFile Receipt { get; set; } = null!;
}

public sealed class ReviewPackageReceiptDto
{
    public Guid Version { get; set; }

    // Admin must explicitly confirm checking the bank credit.
    public bool CreditVerified { get; set; }

    [StringLength(500)]
    public string? AdminNote { get; set; }
}