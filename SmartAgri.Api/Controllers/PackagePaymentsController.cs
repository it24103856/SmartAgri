using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/package-payments")]
[Authorize(Roles = "FARMER,ADMIN")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class PackagePaymentsController : ControllerBase
{
    private readonly PackagePaymentService _service;

    public PackagePaymentsController(PackagePaymentService service)
    {
        _service = service;
    }

    [HttpGet("bookings/{bookingId:int}")]
    public Task<IActionResult> Summary(int bookingId) =>
        Execute(async () => Ok(await _service.Summary(User, bookingId)));

    [Authorize(Roles = "FARMER")]
    [HttpPost("bookings/{bookingId:int}/receipts")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public Task<IActionResult> Submit(
        int bookingId, [FromForm] SubmitPackageReceiptDto dto) =>
        Execute(async () => Ok(await _service.Submit(User, bookingId, dto)));

    [Authorize(Roles = "ADMIN")]
    [HttpGet("pending")]
    public Task<IActionResult> Pending() =>
        Execute(async () => Ok(await _service.Pending(User)));

    [Authorize(Roles = "ADMIN")]
    [HttpPost("receipts/{id:int}/approve")]
    public Task<IActionResult> Approve(
        int id, [FromBody] ReviewPackageReceiptDto dto) =>
        Execute(async () => Ok(await _service.Review(User, id, dto, true)));

    [Authorize(Roles = "ADMIN")]
    [HttpPost("receipts/{id:int}/reject")]
    public Task<IActionResult> Reject(
        int id, [FromBody] ReviewPackageReceiptDto dto) =>
        Execute(async () => Ok(await _service.Review(User, id, dto, false)));

    [HttpGet("receipts/{id:int}")]
    public Task<IActionResult> Receipt(int id) =>
        Execute(async () =>
        {
            var receipt = await _service.Receipt(User, id);
            Response.Headers["X-Content-Type-Options"] = "nosniff";
            return File(receipt.Bytes, receipt.ContentType);
        });

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch (PackageOperationException error)
        {
            return StatusCode(error.StatusCode, new { message = error.Message });
        }
        catch (DbUpdateConcurrencyException)
        {
            return Conflict(new { message = "Data changed. Refresh and retry." });
        }
        catch (DbUpdateException error)
            when (error.InnerException is PostgresException
            {
                SqlState: PostgresErrorCodes.UniqueViolation
            })
        {
            return Conflict(new
            {
                message = "A receipt for this stage already exists. Refresh."
            });
        }
    }
}