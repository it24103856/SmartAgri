using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class CustomerCheckoutRequest
{
    public Guid RequestId { get; set; }

    public bool FromCart { get; set; }

    [Required, StringLength(120)]
    public string FullName { get; set; } = "";

    [Required, EmailAddress, StringLength(200)]
    public string Email { get; set; } = "";

    [Required, Phone, StringLength(30)]
    public string Phone { get; set; } = "";

    [Required, StringLength(500)]
    public string Address { get; set; } = "";

    [Required, StringLength(100)]
    public string City { get; set; } = "";

    [Required, RegularExpression("^(COD|PAYHERE)$")]
    public string PaymentMethod { get; set; } = "COD";

    [Required, MinLength(1), MaxLength(100)]
    public List<CustomerCheckoutLineRequest> Items { get; set; } = [];
}

public sealed class CustomerCheckoutLineRequest
{
    [Range(1, int.MaxValue)]
    public int ProductId { get; set; }

    [Range(1, 100000)]
    public int Quantity { get; set; }

    [Range(typeof(decimal), "0.01", "999999999")]
    public decimal UnitPrice { get; set; }
}