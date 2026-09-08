namespace SmartAgri.Api.Models;

public class SoilRecord
{
    public int Id { get; set; }
    public int FarmId { get; set; }
    public decimal Nitrogen { get; set; }
    public decimal Phosphorus { get; set; }
    public decimal Potassium { get; set; }
    public decimal Ph { get; set; }
    public decimal Moisture { get; set; }
    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
}
