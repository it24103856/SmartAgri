using SmartAgri.Api.DTOs;

namespace SmartAgri.Api.Interfaces;

public interface IFarmService
{
    Task<List<FarmResponseDto>> GetFarmerFarmsAsync(int farmerId);
    Task<FarmResponseDto> GetFarmerFarmByIdAsync(int farmerId, int farmId);
    Task<FarmResponseDto> CreateFarmAsync(int farmerId, CreateFarmDto dto);
    Task<FarmResponseDto> UpdateFarmAsync(int farmerId, int farmId, UpdateFarmDto dto);
    Task DeleteFarmAsync(int farmerId, int farmId);
}
