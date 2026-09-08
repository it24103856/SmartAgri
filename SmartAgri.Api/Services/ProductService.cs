using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Services;

public class ProductService : IProductService
{
    public Task<IEnumerable<string>> GetAllProductsAsync()
    {
        return Task.FromResult<IEnumerable<string>>(new[] { "Product 1", "Product 2" });
    }

    public Task<string?> GetProductByIdAsync(int id)
    {
        return Task.FromResult<string?>($"Product {id}");
    }
}
