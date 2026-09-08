using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Services;

public class OrderService : IOrderService
{
    public Task<IEnumerable<string>> GetAllOrdersAsync()
    {
        return Task.FromResult<IEnumerable<string>>(new[] { "Order 1", "Order 2" });
    }

    public Task<string?> GetOrderByIdAsync(int id)
    {
        return Task.FromResult<string?>($"Order {id}");
    }
}
