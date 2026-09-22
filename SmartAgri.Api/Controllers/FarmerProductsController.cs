using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/farmer-products")]
[Authorize(Roles = "FARMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[RequestSizeLimit(30 * 1024 * 1024)]
[RequestFormLimits(MultipartBodyLengthLimit = 30 * 1024 * 1024)]
public sealed class FarmerProductsController : ControllerBase
{
    private readonly IProductService _products;

    public FarmerProductsController(IProductService products)
    {
        _products = products;
    }

    private int FarmerId
    {
        get
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (!int.TryParse(claim, out var id) || id <= 0)
            {
                throw new ProductOperationException(
                    401, "Please sign in again.");
            }

            return id;
        }
    }

    [HttpGet]
    public Task<IActionResult> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        return Execute(async () =>
            Ok(await _products.GetFarmerProductsAsync(
                FarmerId, page, pageSize)));
    }

    [HttpGet("{id:int}")]
    public Task<IActionResult> Get(int id)
    {
        return Execute(async () =>
            Ok(await _products.GetFarmerProductAsync(FarmerId, id)));
    }

    [HttpPost]
    [Consumes("multipart/form-data")]
    public Task<IActionResult> Create([FromForm] SaveProductDto dto)
    {
        return Execute(async () =>
        {
            var product = await _products.CreateFarmerProductAsync(
                FarmerId, dto);

            return CreatedAtAction(
                nameof(Get),
                new { id = product.Id },
                product);
        });
    }

    [HttpPut("{id:int}")]
    [Consumes("multipart/form-data")]
    public Task<IActionResult> Update(
        int id,
        [FromForm] UpdateProductDto dto)
    {
        return Execute(async () =>
            Ok(await _products.UpdateFarmerProductAsync(
                FarmerId, id, dto)));
    }

    private async Task<IActionResult> Execute(
        Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch (ProductOperationException exception)
        {
            return StatusCode(
                exception.StatusCode,
                new { message = exception.Message });
        }
        catch (DbUpdateConcurrencyException)
        {
            return Conflict(new
            {
                message =
                    "This product changed. Refresh it before saving again."
            });
        }
        catch (DbUpdateException exception)
            when (exception.InnerException is PostgresException
            {
                SqlState: PostgresErrorCodes.ForeignKeyViolation
            })
        {
            return Conflict(new
            {
                message =
                    "Related data changed. Refresh and try again."
            });
        }
    }
}