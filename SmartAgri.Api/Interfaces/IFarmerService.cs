namespace SmartAgri.Api.Interfaces;

public interface IFarmerService
{
    Task<IEnumerable<string>> GetAllFarmersAsync();
    Task<string?> GetFarmerByIdAsync(int id);
}
