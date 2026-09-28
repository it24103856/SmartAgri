using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/farmer-packages")]
[Authorize(Roles = "FARMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class FarmerPackagesController : ControllerBase
{
    private readonly IPackageService _packages;

    public FarmerPackagesController(IPackageService packages)
    {
        _packages = packages;
    }

    private int FarmerId
    {
        get
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (!int.TryParse(claim, out var id) || id <= 0)
            {
                throw new PackageOperationException(401, "Please sign in again.");
            }

            return id;
        }
    }

    [HttpGet]
    public Task<IActionResult> List([FromQuery] string? category)
        => Execute(async () => Ok(await _packages.GetActiveAsync(FarmerId, category)));

    [HttpPost("quote")]
    public Task<IActionResult> Quote([FromBody] CreateBookingDto dto)
        => Execute(async () => Ok(await _packages.QuoteAsync(FarmerId, dto)));

    [HttpPost("bookings")]
    public Task<IActionResult> Book([FromBody] CreateBookingDto dto)
        => Execute(async () => Ok(await _packages.CreateBookingAsync(FarmerId, dto)));

    [HttpGet("bookings")]
    public Task<IActionResult> MyBookings()
        => Execute(async () => Ok(await _packages.GetBookingsForFarmerAsync(FarmerId)));

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch (PackageOperationException exception)
        {
            return StatusCode(exception.StatusCode, new { message = exception.Message });
        }
    }
}
