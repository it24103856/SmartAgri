using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

// Used for both creating and updating a category.
public class SaveCategoryDto
{
    private string _name = string.Empty;

    [Required(ErrorMessage = "Category name is required.")]
    [StringLength(
        100,
        MinimumLength = 2,
        ErrorMessage = "Category name must contain 2 to 100 characters.")]
    public string Name
    {
        get => _name;
        set => _name = (value ?? string.Empty).Trim();
    }

    [StringLength(
        500,
        ErrorMessage = "Description cannot exceed 500 characters.")]
    public string? Description { get; set; }

    public IFormFile? Image { get; set; }
}

public class CategoryResponseDto
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? ImageUrl { get; set; }

    public DateTime CreatedAt { get; set; }

    public int ProductCount { get; set; }
}