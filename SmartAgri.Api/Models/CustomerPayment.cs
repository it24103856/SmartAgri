using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace SmartAgri.Api.Models;

public sealed class CustomerPayment
{
    public int Id { get; set; }
    public int OrderId { get; set; }

    // COD or PAYHERE
    public string Method { get; set; } = "";

    // Unpaid, Pending, Paid, Failed, Cancelled, Chargeback
    public string Status { get; set; } = "Pending";

    [Column(TypeName = "numeric(18,2)")]
    public decimal Amount { get; set; }

    [JsonIgnore]
    public string GatewayOrderId { get; set; } =
        Guid.NewGuid().ToString("N");

    public string? ProviderPaymentId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PaidAt { get; set; }
}