using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/admin/orders")]
[Authorize(Roles = "ADMIN")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class AdminOrdersController : ControllerBase
{
    private readonly AdminOrderService _service;

    public AdminOrdersController(AdminOrderService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] AdminOrderQuery request,
        CancellationToken ct)
    {
        await _service.RequireAdmin(User, ct);

        return Ok(await _service.List(request, ct));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(
        int id,
        CancellationToken ct)
    {
        await _service.RequireAdmin(User, ct);

        return Ok(await _service.Get(id, ct));
    }

    [HttpGet("{id:int}/history")]
    public async Task<IActionResult> History(
        int id,
        CancellationToken ct)
    {
        await _service.RequireAdmin(User, ct);

        return Ok(await _service.History(id, ct));
    }

    [HttpPatch("{id:int}/status")]
    public async Task<IActionResult> UpdateStatus(
        int id,
        [FromBody] UpdateAdminOrderStatusRequest request,
        CancellationToken ct)
    {
        var adminId = await _service.RequireAdmin(User, ct);

        return Ok(
            await _service.UpdateStatus(
                adminId,
                id,
                request,
                ct));
    }
}