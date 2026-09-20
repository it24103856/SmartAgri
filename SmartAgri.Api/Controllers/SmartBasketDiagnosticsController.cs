using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

public sealed class BasketPreviewLine
{
    [Range(1, int.MaxValue)]
    public int ProductId { get; set; }

    [Range(1, 100000)]
    public int Quantity { get; set; }
}

public sealed class BasketPreviewRequest : IValidatableObject
{
    [Required, MinLength(1), MaxLength(50)]
    public List<BasketPreviewLine> Items { get; set; } = new();

    [Required, MaxLength(200)]
    public List<int> ExcludedProductIds { get; set; } = new();

    public IEnumerable<ValidationResult> Validate(
        ValidationContext validationContext)
    {
        if (Items is not null && Items.Any(item => item is null))
        {
            yield return new ValidationResult(
                "Items cannot contain null entries.",
                new[] { nameof(Items) });
        }

        if (ExcludedProductIds is not null &&
            ExcludedProductIds.Any(id => id <= 0))
        {
            yield return new ValidationResult(
                "Excluded product IDs must be positive.",
                new[] { nameof(ExcludedProductIds) });
        }
    }
}

[ApiController]
[Route("api/customer-smart-baskets")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class SmartBasketDiagnosticsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly AgentValidationClient _agent;
    private readonly SmartBasketService _baskets;
    private readonly IWebHostEnvironment _environment;

    public SmartBasketDiagnosticsController(
        ApplicationDbContext db,
        AgentValidationClient agent,
        SmartBasketService baskets,
        IWebHostEnvironment environment)
    {
        _db = db;
        _agent = agent;
        _baskets = baskets;
        _environment = environment;
    }

    [HttpPost("{id:guid}/validate-preview")]
    public async Task<IActionResult> ValidatePreview(
        Guid id,
        [FromBody] BasketPreviewRequest request,
        CancellationToken ct)
    {
        // Temporary development diagnostic endpoint.
        if (!_environment.IsDevelopment())
            return NotFound();

        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var customerId))
        {
            return Unauthorized();
        }

        await _baskets.RequireCustomer(customerId, ct);

        var workflow = await _db.SmartBasketWorkflows
            .AsNoTracking()
            .SingleOrDefaultAsync(
                value => value.Id == id &&
                    value.CustomerId == customerId,
                ct);

        if (workflow is null)
        {
            return NotFound(new
            {
                message = "Smart Basket request not found."
            });
        }

        var ids = request.Items
            .Select(item => item.ProductId)
            .Distinct()
            .ToArray();

        var products = await _db.Products
            .AsNoTracking()
            .Where(product => ids.Contains(product.Id))
            .ToListAsync(ct);

        if (products.Count != ids.Length)
        {
            return BadRequest(new
            {
                message = "One or more products do not exist."
            });
        }

        if (products.Any(product => product.Price <= 0))
        {
            return Conflict(new
            {
                message = "One or more products have an invalid price."
            });
        }

        // Product price, stock and eligibility come from PostgreSQL,
        // not from the customer request.
        var payload = new
        {
            workflow_id = workflow.Id,
            budget_minor = ToMinor(workflow.Budget),
            currency = workflow.Currency,

            products = products.Select(product => new
            {
                id = product.Id,
                name = product.Name,
                unit = product.Unit,
                unit_price_minor = ToMinor(product.Price),
                stock_quantity = product.StockQuantity,
                is_food = product.IsFood,
                approved = product.Status == "APPROVED"
            }).ToArray(),

            excluded_product_ids = request.ExcludedProductIds,

            items = request.Items.Select(item => new
            {
                product_id = item.ProductId,
                quantity = item.Quantity
            }).ToArray()
        };

        var result = await _agent.Validate(payload, ct);

        if (!result.TryGetProperty(
                "workflow_id",
                out var returnedId) ||
            returnedId.ValueKind !=
                System.Text.Json.JsonValueKind.String ||
            !Guid.TryParse(returnedId.GetString(), out var parsedId) ||
            parsedId != workflow.Id)
        {
            throw new BadHttpRequestException(
                "Agent response does not match this workflow.",
                502);
        }

        // Diagnostic only: no proposal, stock or order is saved.
        return Ok(result);
    }

    private static long ToMinor(decimal amount)
    {
        var scaled = amount * 100m;

        if (scaled != decimal.Truncate(scaled) ||
            scaled <= 0 ||
            scaled > 100_000_000_000m)
        {
            throw new BadHttpRequestException(
                "Amount is outside the supported range or precision.",
                409);
        }

        return decimal.ToInt64(scaled);
    }
}