using System.ComponentModel.DataAnnotations;
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
[Route("api/products")]
[Authorize(Roles = "ADMIN")]
[RequestSizeLimit(30 * 1024 * 1024)]
[RequestFormLimits(MultipartBodyLengthLimit = 30 * 1024 * 1024)]
public class ProductsController : ControllerBase
{
    private readonly IProductService _products;

    public ProductsController(IProductService products)
    {
        _products = products;
    }

    private int AdminId
    {
        get
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (!int.TryParse(claim, out var id))
            {
                throw new ProductOperationException(
                    401, "Please sign in again.");
            }

            return id;
        }
    }

    [HttpGet]
    public Task<IActionResult> GetAll()
    {
        return Execute(async () =>
            Ok(await _products.GetAllAsync(AdminId)));
    }

    [HttpGet("{id:int}")]
    public Task<IActionResult> GetById(int id)
    {
        return Execute(async () =>
            Ok(await _products.GetByIdAsync(AdminId, id)));
    }

    [HttpPost]
    [Consumes("multipart/form-data")]
    public Task<IActionResult> Create([FromForm] SaveProductDto dto)
    {
        return Execute(async () =>
        {
            var product = await _products.CreateAsync(AdminId, dto);

            return CreatedAtAction(
                nameof(GetById),
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
            Ok(await _products.UpdateAsync(AdminId, id, dto)));
    }

    [HttpDelete("{id:int}")]
    public Task<IActionResult> Delete(
        int id,
        [FromQuery, Required] Guid? version)
    {
        return Execute(async () =>
        {
            await _products.DeleteAsync(AdminId, id, version);
            return NoContent();
        });
    }

    [HttpPost("{id:int}/approve")]
    public Task<IActionResult> Approve(
        int id,
        [FromBody] ReviewProductDto dto)
    {
        return Execute(async () =>
            Ok(await _products.ReviewAsync(AdminId, id, dto, true)));
    }

    [HttpPost("{id:int}/reject")]
    public Task<IActionResult> Reject(
        int id,
        [FromBody] ReviewProductDto dto)
    {
        return Execute(async () =>
            Ok(await _products.ReviewAsync(AdminId, id, dto, false)));
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
                    "This product changed while you were working. " +
                    "Refresh the list and review the latest details."
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
                    "Related data changed, or this product is used by " +
                    "another record. Refresh and try again."
            });
        }
    }
}