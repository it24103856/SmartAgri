namespace SmartAgri.Api.Interfaces;

public interface IEquipmentService
{
    Task<IEnumerable<string>> GetAllEquipmentAsync();
    Task<string?> GetEquipmentByIdAsync(int id);
}
