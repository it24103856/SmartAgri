using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/customer-orders")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class CustomerOrdersController : ControllerBase
{
    private readonly CustomerCheckoutService _service;

    public CustomerOrdersController(CustomerCheckoutService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        CustomerCheckoutRequest request)
    {
        var userId = await _service.CustomerId(User);
        return Ok(await _service.Create(userId, request));
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var userId = await _service.CustomerId(User);
        return Ok(await _service.List(userId));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var userId = await _service.CustomerId(User);
        return Ok(await _service.Get(userId, id));
    }
}