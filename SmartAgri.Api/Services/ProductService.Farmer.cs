using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public partial class ProductService
{
    private async Task<User> RequireFarmerAsync(int farmerId)
    {
        var user = await _db.Users.FindAsync(farmerId);

        if (user is null)
        {
            throw new ProductOperationException(
                401, "Please sign in again.");
        }

        if (user.Role != "FARMER" || user.Status != "ACTIVE")
        {
            throw new ProductOperationException(
                403, "An active farmer account is required.");
        }

        return user;
    }

    private async Task<Product> FindFarmerProductAsync(
        int farmerId,
        int id)
    {
        return await ProductQuery()
            .SingleOrDefaultAsync(p =>
                p.Id == id &&
                p.CreatedById == farmerId &&
                p.CreatedByRole == "FARMER")
            ?? throw new ProductOperationException(
                404, "Product not found.");
    }

    public async Task<object> GetFarmerProductsAsync(
        int farmerId,
        int page,
        int pageSize)
    {
        await RequireFarmerAsync(farmerId);

        if (page < 1 || page > 10000 ||
            pageSize < 1 || pageSize > 50)
        {
            throw new ProductOperationException(
                400,
                "Page must be 1–10000 and pageSize must be 1–50.");
        }

        var query = ProductQuery()
            .AsNoTracking()
            .Where(p =>
                p.CreatedById == farmerId &&
                p.CreatedByRole == "FARMER");

        var totalCount = await query.CountAsync();

        var products = await query
            .OrderByDescending(p => p.CreatedAt)
            .ThenByDescending(p => p.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return new
        {
            items = products.Select(Map).ToArray(),
            totalCount,
            page,
            pageSize
        };
    }

    public async Task<ProductResponseDto> GetFarmerProductAsync(
        int farmerId,
        int id)
    {
        await RequireFarmerAsync(farmerId);

        return Map(await FindFarmerProductAsync(farmerId, id));
    }

    public async Task<ProductResponseDto> CreateFarmerProductAsync(
        int farmerId,
        SaveProductDto dto)
    {
        var farmer = await RequireFarmerAsync(farmerId);
        var category = await ValidateDetailsAsync(dto);

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            throw new ProductOperationException(
                400, "Product name is required.");
        }

        if (dto.Images.Count == 0)
        {
            throw new ProductOperationException(
                400, "Upload at least one product image.");
        }

        var newImages = await _images.SaveAsync(dto.Images);

        var product = new Product
        {
            CreatedById = farmer.Id,
            CreatedBy = farmer,
            CreatedByRole = "FARMER",

            Status = "PENDING",
            ReviewedById = null,
            ReviewedAt = null,
            RejectionReason = null,

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

    public async Task<ProductResponseDto> UpdateFarmerProductAsync(
        int farmerId,
        int id,
        UpdateProductDto dto)
    {
        await RequireFarmerAsync(farmerId);

        var product = await FindFarmerProductAsync(farmerId, id);
        CheckVersion(product, dto.Version);

        if (product.Status is not
            ("PENDING" or "APPROVED" or "REJECTED"))
        {
            throw new ProductOperationException(
                409, "This product cannot be edited in its current state.");
        }

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            throw new ProductOperationException(
                400, "Product name is required.");
        }

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

        // Every farmer edit is submitted for a fresh admin review.
        product.Status = "PENDING";
        product.ReviewedById = null;
        product.ReviewedBy = null;
        product.ReviewedAt = null;
        product.RejectionReason = null;

        product.UpdatedAt = DateTime.UtcNow;
        product.Version = Guid.NewGuid();

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
}