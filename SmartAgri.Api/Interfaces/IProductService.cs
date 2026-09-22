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

        Task<object> GetFarmerProductsAsync(
    int farmerId, int page, int pageSize);

Task<ProductResponseDto> GetFarmerProductAsync(
    int farmerId, int id);

Task<ProductResponseDto> CreateFarmerProductAsync(
    int farmerId, SaveProductDto dto);

Task<ProductResponseDto> UpdateFarmerProductAsync(
    int farmerId, int id, UpdateProductDto dto);
}