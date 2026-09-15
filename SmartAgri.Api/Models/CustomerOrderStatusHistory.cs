namespace SmartAgri.Api.Models;

public sealed class CustomerOrderStatusHistory
{
    public int Id { get; set; }

    public int OrderId { get; set; }

    public int ChangedByUserId { get; set; }

    public string FromStatus { get; set; } = "";

    public string ToStatus { get; set; } = "";

    public string? Note { get; set; }

    public bool PaymentCollected { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}