using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class AdminOrderQuery
{
    [StringLength(100)]
    public string? Search { get; set; }

    [RegularExpression(
        "^(AwaitingPayment|Confirmed|Preparing|Packed|Dispatched|Delivered|PaymentFailed|PaymentReview)$")]
    public string? Status { get; set; }

    [Range(1, 100000)]
    public int Page { get; set; } = 1;

    [Range(1, 100)]
    public int PageSize { get; set; } = 20;
}

public sealed class UpdateAdminOrderStatusRequest
{
    [Required]
    [RegularExpression("^(Confirmed|Preparing|Packed|Dispatched)$")]
    public string ExpectedStatus { get; set; } = "";

    [Required]
    [RegularExpression("^(Preparing|Packed|Dispatched|Delivered)$")]
    public string Status { get; set; } = "";

    [StringLength(500)]
    public string? Note { get; set; }

    public bool PaymentCollected { get; set; }
}