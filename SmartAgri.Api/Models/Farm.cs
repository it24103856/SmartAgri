namespace SmartAgri.Api.Models;

public class Farm
{
    public int Id { get; set; }
    public int FarmerId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Location { get; set; }
    public decimal TotalArea { get; set; }
    public string? SoilType { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
