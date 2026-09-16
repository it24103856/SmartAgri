using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public class ProductOperationException : Exception
{
    public int StatusCode { get; }

    public ProductOperationException(int statusCode, string message)
        : base(message)
    {
        StatusCode = statusCode;
    }
}

public class ProductService : IProductService
{
    private readonly ApplicationDbContext _db;
    private readonly ProductImageStore _images;

    public ProductService(
        ApplicationDbContext db,
        ProductImageStore images)
    {
        _db = db;
        _images = images;
    }

    private IQueryable<Product> ProductQuery()
    {
        return _db.Products
            .Include(p => p.Category)
            .Include(p => p.CreatedBy)
            .Include(p => p.ReviewedBy);
    }

    private async Task<User> RequireAdminAsync(int adminId)
    {
        var user = await _db.Users.FindAsync(adminId);

        if (user is null)
            throw new ProductOperationException(401, "Please sign in again.");

        if (user.Role != "ADMIN" || user.Status != "ACTIVE")
        {
            throw new ProductOperationException(
                403, "An active administrator account is required.");
        }

        return user;
    }

    private async Task<Product> FindProductAsync(int id)
    {
        return await ProductQuery().FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new ProductOperationException(404, "Product not found.");
    }

    private async Task<Category> ValidateDetailsAsync(SaveProductDto dto)
    {
        if (decimal.Round(dto.Price, 2) != dto.Price)
        {
            throw new ProductOperationException(
                400, "Price can have up to 2 decimal places.");
        }

        if (dto.WeightKg.HasValue &&
            decimal.Round(dto.WeightKg.Value, 3) != dto.WeightKg.Value)
        {
            throw new ProductOperationException(
                400, "Weight can have up to 3 decimal places.");
        }

        return await _db.Categories.FindAsync(dto.CategoryId)
            ?? throw new ProductOperationException(
                400, "Select an existing category.");
    }

    private static void CheckVersion(Product product, Guid? version)
    {
        if (!version.HasValue)
            throw new ProductOperationException(400, "Product version is required.");

        if (product.Version != version.Value)
        {
            throw new ProductOperationException(
                409,
                "This product has changed. Close this window, refresh the list, " +
                "and review the latest details.");
        }
    }

    private static void ApplyDetails(
        Product product,
        SaveProductDto dto,
        Category category)
    {
        product.Name = dto.Name.Trim();

        product.Description = string.IsNullOrWhiteSpace(dto.Description)
            ? null
            : dto.Description.Trim();

        product.CategoryId = category.Id;
        product.Category = category;

        product.Price = dto.Price;
        product.Unit = dto.Unit;
        product.WeightKg = dto.WeightKg;
        product.StockQuantity = dto.StockQuantity;
        product.IsFood = dto.IsFood;
        product.NutritionFacts = dto.IsFood ? dto.NutritionFacts?.Trim() : null;
        product.NutritionBasis = dto.IsFood ? dto.NutritionBasis?.Trim() : null;
        product.NutritionSourceName = dto.IsFood ? dto.NutritionSourceName?.Trim() : null;
        product.NutritionSourceUrl = dto.IsFood ? dto.NutritionSourceUrl?.Trim() : null;
    }

    public async Task<List<ProductResponseDto>> GetAllAsync(int adminId)
    {
        await RequireAdminAsync(adminId);

        var products = await ProductQuery()
            .AsNoTracking()
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();

        return products.Select(Map).ToList();
    }

    public async Task<ProductResponseDto> GetByIdAsync(int adminId, int id)
    {
        await RequireAdminAsync(adminId);
        return Map(await FindProductAsync(id));
    }

    public async Task<ProductResponseDto> CreateAsync(
        int adminId,
        SaveProductDto dto)
    {
        var admin = await RequireAdminAsync(adminId);
        var category = await ValidateDetailsAsync(dto);

        if (dto.Images.Count == 0)
        {
            throw new ProductOperationException(
                400, "Upload at least one product image.");
        }

        var newImages = await _images.SaveAsync(dto.Images);

        var product = new Product
        {
            CreatedById = admin.Id,
            CreatedBy = admin,
            CreatedByRole = "ADMIN",

            Status = "APPROVED",
            ReviewedById = admin.Id,
            ReviewedBy = admin,
            ReviewedAt = DateTime.UtcNow,

            CreatedAt = DateTime.UtcNow,
            ImageUrls = newImages,
            ImageUrl = newImages[0],
            Version = Guid.NewGuid()
        };

        ApplyDetails(product, dto, category);

        try
        {
            _db.Products.Add(product);
            await _db.SaveChangesAsync();
        }
        catch
        {
            _images.DeleteFiles(newImages);
            throw;
        }

        return Map(product);
    }

    public async Task<ProductResponseDto> UpdateAsync(
        int adminId,
        int id,
        UpdateProductDto dto)
    {
        await RequireAdminAsync(adminId);

        var product = await FindProductAsync(id);
        CheckVersion(product, dto.Version);

        var category = await ValidateDetailsAsync(dto);
        var previousImages = CurrentImages(product);

        if (dto.Images.Count == 0 && previousImages.Count == 0)
        {
            throw new ProductOperationException(
                400, "Upload at least one product image.");
        }

        var newImages = dto.Images.Count > 0
            ? await _images.SaveAsync(dto.Images)
            : new List<string>();

        ApplyDetails(product, dto, category);

        if (newImages.Count > 0)
        {
            product.ImageUrls = newImages;
            product.ImageUrl = newImages[0];
        }

        product.UpdatedAt = DateTime.UtcNow;
        product.Version = Guid.NewGuid();

        // Approval state is changed only through the review endpoints.
        try
        {
            await _db.SaveChangesAsync();
        }
        catch
        {
            _images.DeleteFiles(newImages);
            throw;
        }

        if (newImages.Count > 0)
        {
            _images.DeleteFiles(previousImages);
        }

        return Map(product);
    }

    public async Task DeleteAsync(
        int adminId,
        int id,
        Guid? version)
    {
        await RequireAdminAsync(adminId);

        var product = await FindProductAsync(id);
        CheckVersion(product, version);

        var images = CurrentImages(product);

        _db.Products.Remove(product);
        await _db.SaveChangesAsync();

        // Remove files only after the database deletion succeeds.
        _images.DeleteFiles(images);
    }

    public async Task<ProductResponseDto> ReviewAsync(
        int adminId,
        int id,
        ReviewProductDto dto,
        bool approve)
    {
        var admin = await RequireAdminAsync(adminId);
        var product = await FindProductAsync(id);

        CheckVersion(product, dto.Version);

        if (product.Status != "PENDING")
        {
            throw new ProductOperationException(
                409, "Only pending products can be approved or rejected.");
        }

        var reason = dto.Reason?.Trim();

        if (!approve && (string.IsNullOrEmpty(reason) || reason.Length < 3))
        {
            throw new ProductOperationException(
                400, "Enter a rejection reason with at least 3 characters.");
        }

        product.Status = approve ? "APPROVED" : "REJECTED";
        product.RejectionReason = approve ? null : reason;

        product.ReviewedById = admin.Id;
        product.ReviewedBy = admin;
        product.ReviewedAt = DateTime.UtcNow;
        product.UpdatedAt = DateTime.UtcNow;
        product.Version = Guid.NewGuid();

        await _db.SaveChangesAsync();

        return Map(product);
    }

    private static List<string> CurrentImages(Product product)
    {
        if (product.ImageUrls.Count > 0)
            return product.ImageUrls.ToList();

        return string.IsNullOrWhiteSpace(product.ImageUrl)
            ? new List<string>()
            : new List<string> { product.ImageUrl! };
    }

    private static ProductResponseDto Map(Product product)
    {
        return new ProductResponseDto
        {
            IsFood = product.IsFood,
            NutritionFacts = product.NutritionFacts,
            NutritionBasis = product.NutritionBasis,
            NutritionSourceName = product.NutritionSourceName,
            NutritionSourceUrl = product.NutritionSourceUrl,
            Id = product.Id,
            Name = product.Name,
            Description = product.Description,

            CategoryId = product.CategoryId,
            CategoryName = product.Category.Name,

            Price = product.Price,
            Unit = product.Unit,
            WeightKg = product.WeightKg,
            StockQuantity = product.StockQuantity,

            ImageUrls = CurrentImages(product),
            Status = product.Status,

            CreatedById = product.CreatedById,
            CreatedByName = product.CreatedBy?.FullName ?? "Existing catalog",
            CreatedByRole = product.CreatedByRole,

            ReviewedByName = product.ReviewedBy?.FullName,
            RejectionReason = product.RejectionReason,

            CreatedAt = product.CreatedAt,
            UpdatedAt = product.UpdatedAt,
            ReviewedAt = product.ReviewedAt,

            Version = product.Version
        };
    }
}
