using SmartAgri.Api.DTOs;

namespace SmartAgri.Api.Interfaces;

public interface IProductService
{
    Task<List<ProductResponseDto>> GetAllAsync(int adminId);

    Task<ProductResponseDto> GetByIdAsync(int adminId, int id);

    Task<ProductResponseDto> CreateAsync(
        int adminId, SaveProductDto dto);

    Task<ProductResponseDto> UpdateAsync(
        int adminId, int id, UpdateProductDto dto);

    Task DeleteAsync(
        int adminId, int id, Guid? version);

    Task<ProductResponseDto> ReviewAsync(
        int adminId,
        int id,
        ReviewProductDto dto,
        bool approve);
}