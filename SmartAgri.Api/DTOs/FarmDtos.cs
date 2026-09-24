using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace SmartAgri.Api.DTOs;

public class CreateFarmDto
{
    [Required(ErrorMessage = "Farm name is required")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Farm name must be between 2 and 100 characters")]
    public string Name { get; set; } = string.Empty;

    [StringLength(200, ErrorMessage = "Location cannot exceed 200 characters")]
    public string? Location { get; set; }

    [Range(typeof(decimal), "0.01", "1000000", ErrorMessage = "Total area must be greater than 0")]
    public decimal TotalArea { get; set; }

    [Required(ErrorMessage = "Area unit is required")]
    [RegularExpression("^(Acres|Perches|Hectares)$", ErrorMessage = "Area unit must be Acres, Perches, or Hectares")]
    public string AreaUnit { get; set; } = "Acres";

    [StringLength(50)]
    public string? SoilType { get; set; }

    [StringLength(50)]
    public string? IrrigationType { get; set; }

    [StringLength(250)]
    public string? MainCrops { get; set; }

    [StringLength(1000)]
    public string? Description { get; set; }

    public List<IFormFile> Images { get; set; } = new();
}

public class UpdateFarmDto : CreateFarmDto
{
    /// <summary>
    /// URLs of images that were previously uploaded and should be retained.
    /// </summary>
    public List<string> ExistingImageUrls { get; set; } = new();
}

public class FarmResponseDto
{
    public int Id { get; set; }
    public int FarmerId { get; set; }
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
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
