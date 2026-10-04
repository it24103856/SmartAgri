using System.Text.Json.Serialization;
namespace SmartAgri.Api.Models;

public sealed class OrderPaymentProof
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public CustomerOrder Order { get; set; } = null!;
    public decimal Amount { get; set; }
    public string TransferReference { get; set; } = "";
    [JsonIgnore] public byte[] Receipt { get; set; } = [];
    [JsonIgnore] public string? ReceiptObjectKey { get; set; }
    public string ContentType { get; set; } = "image/jpeg";
    public string Status { get; set; } = "SUBMITTED";
    public string? AdminNote { get; set; }
    public int? ReviewedById { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReviewedAt { get; set; }
    public Guid Version { get; set; } = Guid.NewGuid();
}
