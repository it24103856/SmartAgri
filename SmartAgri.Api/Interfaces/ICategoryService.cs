using SmartAgri.Api.DTOs;

namespace SmartAgri.Api.Interfaces;

public interface ICategoryService
{
    Task<List<CategoryResponseDto>> GetAllAsync();

    Task<CategoryResponseDto?> GetByIdAsync(int id);

    Task<CategoryResponseDto> CreateAsync(SaveCategoryDto dto);

    Task<CategoryResponseDto?> UpdateAsync(int id, SaveCategoryDto dto);

    Task<CategoryDeleteResult> DeleteAsync(int id);
}

public enum CategoryDeleteResult
{
    Deleted,
    NotFound,
    InUse
}