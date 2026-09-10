using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public class CategoryService : ICategoryService
{
    private readonly ApplicationDbContext _context;

    private readonly CategoryImageStore _images;

    public CategoryService(ApplicationDbContext context, CategoryImageStore images)
    {
        _context = context;
        _images = images;
    }

    private IQueryable<CategoryResponseDto> CategoryQuery()
    {
        return _context.Categories
            .AsNoTracking()
            .Select(category => new CategoryResponseDto
            {
                Id = category.Id,
                Name = category.Name,
                Description = category.Description,
                ImageUrl = category.ImageUrl,
                CreatedAt = category.CreatedAt,
                ProductCount = category.Products.Count
            });
    }

    public async Task<List<CategoryResponseDto>> GetAllAsync()
    {
        return await CategoryQuery()
            .OrderBy(category => category.Name)
            .ToListAsync();
    }

    public async Task<CategoryResponseDto?> GetByIdAsync(int id)
    {
        return await CategoryQuery()
            .FirstOrDefaultAsync(category => category.Id == id);
    }

    public async Task<CategoryResponseDto> CreateAsync(
        SaveCategoryDto dto)
    {
        var name = dto.Name.Trim();

        var category = new Category
        {
            Name = name,
            NormalizedName = name.ToUpperInvariant(),
            Description = CleanDescription(dto.Description),
            CreatedAt = DateTime.UtcNow
        };

        var uploaded = dto.Image is null
            ? new List<string>()
            : await _images.SaveAsync(new[] { dto.Image });
        category.ImageUrl = uploaded.FirstOrDefault();
        _context.Categories.Add(category);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            _images.DeleteFiles(uploaded);
            throw;
        }

        return new CategoryResponseDto
        {
            Id = category.Id,
            Name = category.Name,
            Description = category.Description,
                ImageUrl = category.ImageUrl,
            CreatedAt = category.CreatedAt,
            ProductCount = 0
        };
    }

    public async Task<CategoryResponseDto?> UpdateAsync(
        int id,
        SaveCategoryDto dto)
    {
        var category = await _context.Categories.FindAsync(id);

        if (category is null)
        {
            return null;
        }

        var name = dto.Name.Trim();

        category.Name = name;
        category.NormalizedName = name.ToUpperInvariant();
        category.Description = CleanDescription(dto.Description);

        var oldImage = category.ImageUrl;
        var uploaded = dto.Image is null
            ? new List<string>()
            : await _images.SaveAsync(new[] { dto.Image });
        if (uploaded.Count > 0) category.ImageUrl = uploaded[0];

        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            _images.DeleteFiles(uploaded);
            throw;
        }
        if (uploaded.Count > 0 && oldImage is not null)
            _images.DeleteFiles(new[] { oldImage });

        return await GetByIdAsync(id);
    }

    public async Task<CategoryDeleteResult> DeleteAsync(int id)
    {
        var category = await _context.Categories.FindAsync(id);

        if (category is null)
        {
            return CategoryDeleteResult.NotFound;
        }

        var hasProducts = await _context.Products
            .AnyAsync(product => product.CategoryId == id);

        if (hasProducts)
        {
            return CategoryDeleteResult.InUse;
        }

        _context.Categories.Remove(category);

        try
        {
            await _context.SaveChangesAsync();

            if (category.ImageUrl is not null)
                _images.DeleteFiles(new[] { category.ImageUrl });

            return CategoryDeleteResult.Deleted;
        }
        catch (DbUpdateException exception)
            when (exception.InnerException is PostgresException
            {
                SqlState: PostgresErrorCodes.ForeignKeyViolation
            })
        {
            // A product could have been added after the check above.
            return CategoryDeleteResult.InUse;
        }
    }

    private static string? CleanDescription(string? description)
    {
        return string.IsNullOrWhiteSpace(description)
            ? null
            : description.Trim();
    }
}