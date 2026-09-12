using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class UpdateCustomerProfileDto
{
    [Required, StringLength(120)]
    public string FullName { get; set; } = "";

    [Required]
    [RegularExpression(
        @"^\+?[0-9][0-9 ()-]{5,23}[0-9]$",
        ErrorMessage = "Enter a valid phone number.")]
    public string Phone { get; set; } = "";

    [Required, StringLength(250)]
    public string Address { get; set; } = "";

    [Required, StringLength(100)]
    public string City { get; set; } = "";

    [Required, StringLength(100)]
    public string Province { get; set; } = "";

    public IFormFile? Photo { get; set; }
}