namespace SmartAgri.Api.Models;

public class EnvironmentalRecord
{
    public int Id { get; set; }
    public int FarmId { get; set; }
    public decimal Temperature { get; set; }
    public decimal Humidity { get; set; }
    public decimal Rainfall { get; set; }
    public decimal WindSpeed { get; set; }
    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
}
