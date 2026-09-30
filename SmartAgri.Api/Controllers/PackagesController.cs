using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/packages")]
[Authorize(Roles = "ADMIN")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class PackagesController : ControllerBase
{
    private readonly IPackageService _packages;

    public PackagesController(IPackageService packages)
    {
        _packages = packages;
    }

    private int AdminId
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
    public Task<IActionResult> List()
        => Execute(async () => Ok(await _packages.GetAllAsync(AdminId)));

    [HttpGet("{id:int}")]
    public Task<IActionResult> Get(int id)
        => Execute(async () => Ok(await _packages.GetByIdAsync(AdminId, id)));

    [HttpPost]
    public Task<IActionResult> Create([FromBody] SavePackageDto dto)
    {
        return Execute(async () =>
        {
            var package = await _packages.CreateAsync(AdminId, dto);
            return CreatedAtAction(nameof(Get), new { id = package.Id }, package);
        });
    }

    [HttpPut("{id:int}")]
    public Task<IActionResult> Update(int id, [FromBody] SavePackageDto dto)
        => Execute(async () => Ok(await _packages.UpdateAsync(AdminId, id, dto)));

    [HttpPost("with-images")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(32 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 32 * 1024 * 1024)]
    public Task<IActionResult> CreateWithImages([FromForm] SavePackageImagesDto dto)
        => Execute(async () =>
        {
            var package = await _packages.SaveWithImagesAsync(AdminId, null, dto);
            return CreatedAtAction(nameof(Get), new { id = package.Id }, package);
        });

    [HttpPut("{id:int}/with-images")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(32 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 32 * 1024 * 1024)]
    public Task<IActionResult> UpdateWithImages(int id, [FromForm] SavePackageImagesDto dto)
        => Execute(async () => Ok(await _packages.SaveWithImagesAsync(AdminId, id, dto)));

    [HttpDelete("{id:int}")]
    public Task<IActionResult> Delete(int id, [FromQuery] Guid version)
    {
        return Execute(async () =>
        {
            await _packages.DeleteAsync(AdminId, id, version);
            return NoContent();
        });
    }

    [HttpGet("bookings/pending")]
    public Task<IActionResult> PendingBookings()
        => Execute(async () => Ok(await _packages.GetPendingBookingsAsync(AdminId)));

    [HttpPost("bookings/{bookingId:int}/approve")]
    public Task<IActionResult> ApproveBooking(int bookingId, [FromBody] ReviewBookingDto dto)
    {
        return Execute(async () =>
            Ok(await _packages.ReviewBookingAsync(AdminId, bookingId, dto, approve: true)));
    }

    [HttpPost("bookings/{bookingId:int}/reject")]
    public Task<IActionResult> RejectBooking(int bookingId, [FromBody] ReviewBookingDto dto)
    {
        return Execute(async () =>
            Ok(await _packages.ReviewBookingAsync(AdminId, bookingId, dto, approve: false)));
    }

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

    [HttpGet("bookings")]
public Task<IActionResult> AllBookings()
{
    return Execute(async () =>
        Ok(await _packages.GetAllBookingsAsync(AdminId)));
}

[HttpPost("bookings/{bookingId:int}/complete")]
public Task<IActionResult> CompleteBooking(
    int bookingId,
    [FromBody] ReviewBookingDto dto)
{
    return Execute(async () =>
        Ok(await _packages.CompleteBookingAsync(
            AdminId, bookingId, dto)));
}
}
