namespace SmartAgri.Api.Models;

public class CropHistory
{
    public int Id { get; set; }
    public int FarmId { get; set; }
    public string CropName { get; set; } = string.Empty;
    public int SeasonYear { get; set; }
    public decimal Yield { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
