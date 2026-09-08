using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Services;

public class FarmerService : IFarmerService
{
    public Task<IEnumerable<string>> GetAllFarmersAsync()
    {
        return Task.FromResult<IEnumerable<string>>(new[] { "Farmer 1", "Farmer 2" });
    }

    public Task<string?> GetFarmerByIdAsync(int id)
    {
        return Task.FromResult<string?>($"Farmer {id}");
    }
}
