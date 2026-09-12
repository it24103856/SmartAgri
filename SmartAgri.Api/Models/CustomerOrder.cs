using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace SmartAgri.Api.Models;

public sealed class CustomerOrder
{
    public int Id { get; set; }
    public int UserId { get; set; }

    public Guid RequestId { get; set; }

    [JsonIgnore]
    public string RequestHash { get; set; } = "";

    public string Status { get; set; } = "AwaitingPayment";

    public string FullName { get; set; } = "";
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Address { get; set; } = "";
    public string City { get; set; } = "";

    public string Currency { get; set; } = "LKR";

    [Column(TypeName = "numeric(18,2)")]
    public decimal Subtotal { get; set; }

    [Column(TypeName = "numeric(18,2)")]
    public decimal DeliveryFee { get; set; }

    [Column(TypeName = "numeric(18,2)")]
    public decimal TotalAmount { get; set; }

    public string? ReviewReason { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public List<CustomerOrderLine> Items { get; set; } = [];

    public CustomerPayment Payment { get; set; } = new();
}

public sealed class CustomerOrderLine
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }

    public string Name { get; set; } = "";
    public string Unit { get; set; } = "";

    public int Quantity { get; set; }

    [Column(TypeName = "numeric(18,2)")]
    public decimal UnitPrice { get; set; }

    [NotMapped]
    public decimal LineTotal => UnitPrice * Quantity;

    [JsonIgnore]
    public int? SourceCartItemId { get; set; }
}