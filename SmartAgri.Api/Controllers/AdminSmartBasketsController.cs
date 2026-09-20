using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/admin-smart-baskets")]
[Authorize(Roles = "ADMIN")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class AdminSmartBasketsController : ControllerBase
{
    private readonly AdminSmartBasketService _service;

    public AdminSmartBasketsController(AdminSmartBasketService service)
    {
        _service = service;
    }

    private int AdminId()
    {
        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            throw new BadHttpRequestException(
                "Please sign in again.", 401);
        }

        return id;
    }

    [HttpGet]
    public async Task<IActionResult> List(
        CancellationToken ct,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        return Ok(await _service.List(
            AdminId(), page, pageSize, ct));
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(
        Guid id,
        CancellationToken ct)
    {
        return Ok(await _service.Get(AdminId(), id, ct));
    }

    [HttpPost("{id:guid}/decision")]
    public async Task<IActionResult> Decide(
        Guid id,
        [FromBody] SmartBasketDecisionRequest request,
        CancellationToken ct)
    {
        var adminId = AdminId();

        await _service.Decide(adminId, id, request, ct);

        return Ok(await _service.Get(adminId, id, ct));
    }
}