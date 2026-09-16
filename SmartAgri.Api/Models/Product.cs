namespace SmartAgri.Api.Models;

public class Product
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }

    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;

    public decimal Price { get; set; }
    public string Unit { get; set; } = "piece";
    public decimal? WeightKg { get; set; }
    public int StockQuantity { get; set; }

    // Kept for compatibility with the existing model.
    public string? ImageUrl { get; set; }

    public List<string> ImageUrls { get; set; } = new();

    public string Status { get; set; } = "PENDING";

    // Nullable to support products that existed before this feature.
    public int? CreatedById { get; set; }
    public User? CreatedBy { get; set; }

    public string CreatedByRole { get; set; } = "ADMIN";

    public int? ReviewedById { get; set; }
    public User? ReviewedBy { get; set; }

    public string? RejectionReason { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public DateTime? ReviewedAt { get; set; }

    // Prevents an old screen from overwriting newer changes.
    public Guid Version { get; set; } = Guid.NewGuid();

        public bool IsFood { get; set; }

    public string? NutritionFacts { get; set; }

    public string? NutritionBasis { get; set; }

    public string? NutritionSourceName { get; set; }

    public string? NutritionSourceUrl { get; set; }
}