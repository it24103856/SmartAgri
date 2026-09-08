namespace SmartAgri.Api.Interfaces;

public interface IOrderService
{
    Task<IEnumerable<string>> GetAllOrdersAsync();
    Task<string?> GetOrderByIdAsync(int id);
}
