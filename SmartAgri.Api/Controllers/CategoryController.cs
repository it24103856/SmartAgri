using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/catalog")]
[Authorize(Roles = "CUSTOMER,ADMIN")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class CatalogController : ControllerBase
{
    private readonly ApplicationDbContext _db;

    public CatalogController(ApplicationDbContext db)
    {
        _db = db;
    }

    private async Task<bool> CanBrowseAsync(CancellationToken ct)
    {
        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var userId))
        {
            return false;
        }

        return await _db.Users
            .AsNoTracking()
            .AnyAsync(
                u => u.Id == userId
                     && u.Status == "ACTIVE"
                     && (u.Role == "CUSTOMER" || u.Role == "ADMIN"),
                ct);
    }

    private IQueryable<Product> ApprovedProducts()
    {
        return _db.Products
            .AsNoTracking()
            .Where(p => p.Status == "APPROVED");
    }

    private static IQueryable<CatalogProductDto> Project(
        IQueryable<Product> products)
    {
        return products.Select(p => new CatalogProductDto
        {
            IsFood = p.IsFood,
            NutritionFacts = p.NutritionFacts,
            NutritionBasis = p.NutritionBasis,
            NutritionSourceName = p.NutritionSourceName,
            NutritionSourceUrl = p.NutritionSourceUrl,
            Id = p.Id,
            Name = p.Name,
            Description = p.Description,
            CategoryId = p.CategoryId,
            CategoryName = p.Category!.Name,
            Price = p.Price,
            Unit = p.Unit,
            WeightKg = p.WeightKg,
            StockQuantity = p.StockQuantity,
            ImageUrls = p.ImageUrls,
            ImageUrl = p.ImageUrl
        });
    }

    // GET /api/catalog/categories
    [HttpGet("categories")]
    public async Task<IActionResult> Categories(CancellationToken ct)
    {
        if (!await CanBrowseAsync(ct))
        {
            return Forbid();
        }

        var categories = await _db.Categories
            .AsNoTracking()
            .OrderBy(c => c.Name)
            .Select(c => new
            {
                c.Id,
                c.Name,

                ProductCount = c.Products.Count(
                    p => p.Status == "APPROVED"),

                c.ImageUrl
            })
            .ToListAsync(ct);

        return Ok(categories);
    }

    // GET /api/catalog/products
    [HttpGet("products")]
    public async Task<IActionResult> Products(
        [FromQuery] string? search,
        [FromQuery] int? categoryId,
        [FromQuery] string sort = "latest",
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 12,
        CancellationToken ct = default)
    {
        if (!await CanBrowseAsync(ct))
        {
            return Forbid();
        }

        if (page < 1 || page > 100000 ||
            pageSize < 1 || pageSize > 40)
        {
            return BadRequest(new
            {
                message = "Invalid page or page size."
            });
        }

        if (categoryId.HasValue && categoryId.Value < 1)
        {
            return BadRequest(new
            {
                message = "Invalid category."
            });
        }

        var term = search?.Trim();

        if (term?.Length > 100)
        {
            return BadRequest(new
            {
                message = "Search must be 100 characters or fewer."
            });
        }

        if (sort != "latest" &&
            sort != "price_asc" &&
            sort != "price_desc")
        {
            return BadRequest(new
            {
                message = "Invalid sort option."
            });
        }

        var query = ApprovedProducts();

        if (categoryId.HasValue)
        {
            query = query.Where(
                p => p.CategoryId == categoryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(term))
        {
            term = term.ToLowerInvariant();

            query = query.Where(p =>
                p.Name.ToLower().Contains(term) ||
                (p.Description != null &&
                 p.Description.ToLower().Contains(term)));
        }

        var totalCount = await query.CountAsync(ct);

        var lastPage = Math.Max(
            1,
            (int)Math.Ceiling(totalCount / (double)pageSize));

        page = Math.Min(page, lastPage);

        query = sort switch
        {
            "price_asc" => query
                .OrderBy(p => p.Price)
                .ThenBy(p => p.Id),

            "price_desc" => query
                .OrderByDescending(p => p.Price)
                .ThenBy(p => p.Id),

            _ => query
                .OrderByDescending(p => p.CreatedAt)
                .ThenByDescending(p => p.Id)
        };

        var items = await Project(
                query
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize))
            .ToListAsync(ct);

        return Ok(new
        {
            items,
            totalCount,
            page,
            pageSize
        });
    }

    // GET /api/catalog/products/5
    [HttpGet("products/{id:int}")]
    public async Task<IActionResult> ProductDetails(
        int id,
        CancellationToken ct)
    {
        if (!await CanBrowseAsync(ct))
        {
            return Forbid();
        }

        var product = await Project(
                ApprovedProducts().Where(p => p.Id == id))
            .SingleOrDefaultAsync(ct);

        if (product == null)
        {
            return NotFound(new
            {
                message = "This product is no longer available."
            });
        }

        return Ok(product);
    }
}

public sealed class CatalogProductDto
{
    public bool IsFood { get; set; }
    public string? NutritionFacts { get; set; }
    public string? NutritionBasis { get; set; }
    public string? NutritionSourceName { get; set; }
    public string? NutritionSourceUrl { get; set; }

    public int Id { get; set; }

    public string Name { get; set; } = "";

    public string? Description { get; set; }

    public int CategoryId { get; set; }

    public string CategoryName { get; set; } = "";

    public decimal Price { get; set; }

    public string Unit { get; set; } = "piece";

    public decimal? WeightKg { get; set; }

    public int StockQuantity { get; set; }

    public List<string> ImageUrls { get; set; } = new();

    public string? ImageUrl { get; set; }
}
