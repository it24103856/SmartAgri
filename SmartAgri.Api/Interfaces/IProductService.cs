namespace SmartAgri.Api.Interfaces;

public interface IProductService
{
    Task<IEnumerable<string>> GetAllProductsAsync();
    Task<string?> GetProductByIdAsync(int id);
}
