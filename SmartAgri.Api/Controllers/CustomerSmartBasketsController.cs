using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/customer-smart-baskets")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class CustomerSmartBasketsController : ControllerBase
{
    private readonly SmartBasketService _service;

    public CustomerSmartBasketsController(SmartBasketService service)
    {
        _service = service;
    }

    private int CustomerId()
    {
        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            throw new BadHttpRequestException(
                "Please sign in again.",
                401);
        }

        return id;
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] CreateSmartBasketRequest request,
        CancellationToken ct)
    {
        var workflow = await _service.Create(
            CustomerId(),
            request,
            ct);

        return AcceptedAtAction(
            nameof(Get),
            new { id = workflow.Id },
            new
            {
                workflow.Id,
                workflow.Status,
                workflow.Budget,
                workflow.Currency,
                workflow.CreatedAt
            });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        CancellationToken ct,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        return Ok(await _service.List(
            CustomerId(),
            page,
            pageSize,
            ct));
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(
        Guid id,
        CancellationToken ct)
    {
        return Ok(await _service.Get(
            CustomerId(),
            id,
            ct));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(
        Guid id,
        CancellationToken ct)
    {
        await _service.Delete(CustomerId(), id, ct);
        return NoContent();
    }

    [HttpPut("{id:guid}/review")]
public async Task<IActionResult> Review(
    Guid id,
    [FromBody] SmartBasketReviewRequest request,
    CancellationToken ct)
{
    var customerId = CustomerId();

    await _service.Review(
        customerId,
        id,
        request,
        ct);

    return Ok(await _service.Get(
        customerId,
        id,
        ct));
}
}
