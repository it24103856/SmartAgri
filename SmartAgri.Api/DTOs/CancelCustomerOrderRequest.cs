using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class CancelCustomerOrderRequest
{
    [Required]
    [StringLength(500, MinimumLength = 5)]
    public string Reason { get; set; } = "";
}