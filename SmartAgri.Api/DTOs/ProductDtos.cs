using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public class SaveProductDto
{
    private string _name = string.Empty;

    [Required]
    [StringLength(150, MinimumLength = 2)]
    public string Name
    {
        get => _name;
        set => _name = (value ?? string.Empty).Trim();
    }

    [StringLength(2000)]
    public string? Description { get; set; }

    [Range(1, int.MaxValue)]
    public int CategoryId { get; set; }

    [Range(typeof(decimal), "0.01", "999999999.99")]
    public decimal Price { get; set; }

    [Required]
    [RegularExpression(
        "^(kg|g|piece|pack|litre)$",
        ErrorMessage = "Select a valid product unit.")]
    public string Unit { get; set; } = "piece";

    [Range(typeof(decimal), "0.001", "999999.999")]
    public decimal? WeightKg { get; set; }

    [Range(0, 1000000)]
    public int StockQuantity { get; set; }

    public List<IFormFile> Images { get; set; } = new();
}

public class UpdateProductDto : SaveProductDto
{
    [Required]
    public Guid? Version { get; set; }
}

public class ReviewProductDto
{
    [Required]
    public Guid? Version { get; set; }

    [StringLength(500)]
    public string? Reason { get; set; }
}

public class ProductResponseDto
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }

    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;

    public decimal Price { get; set; }
    public string Unit { get; set; } = string.Empty;
    public decimal? WeightKg { get; set; }
    public int StockQuantity { get; set; }

    public List<string> ImageUrls { get; set; } = new();

    public string Status { get; set; } = string.Empty;

    public int? CreatedById { get; set; }
    public string CreatedByName { get; set; } = string.Empty;
    public string CreatedByRole { get; set; } = string.Empty;

    public string? ReviewedByName { get; set; }
    public string? RejectionReason { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public DateTime? ReviewedAt { get; set; }

    public Guid Version { get; set; }
}