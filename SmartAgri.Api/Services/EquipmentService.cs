using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Services;

public class EquipmentService : IEquipmentService
{
    public Task<IEnumerable<string>> GetAllEquipmentAsync()
    {
        return Task.FromResult<IEnumerable<string>>(new[] { "Equipment 1", "Equipment 2" });
    }

    public Task<string?> GetEquipmentByIdAsync(int id)
    {
        return Task.FromResult<string?>($"Equipment {id}");
    }
}
