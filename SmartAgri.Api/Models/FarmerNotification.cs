namespace SmartAgri.Api.Models;

public sealed class FarmerNotification
{
    public int Id { get; set; }
    public int FarmerId { get; set; }
    public int ProductId { get; set; }
    public string Title { get; set; } = "";
    public string Message { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; set; }
}
