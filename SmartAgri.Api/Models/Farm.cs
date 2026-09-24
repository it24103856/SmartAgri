namespace SmartAgri.Api.Models;

public class Farm
{
    public int Id { get; set; }
    public int FarmerId { get; set; }
    public User? Farmer { get; set; }

    public string Name { get; set; } = string.Empty;
    public string? Location { get; set; }
    public decimal TotalArea { get; set; }
    public string AreaUnit { get; set; } = "Acres";
    public string? SoilType { get; set; }
    public string? IrrigationType { get; set; }
    public string? MainCrops { get; set; }
    public string? Description { get; set; }

    public List<string> ImageUrls { get; set; } = new();

    public string Status { get; set; } = "ACTIVE";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
