using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;
namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/order-payments")]
[Authorize(Roles = "CUSTOMER,FARMER,ADMIN")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class OrderPaymentsController(CustomerCheckoutService service) : ControllerBase
{
    [HttpGet("bank-details")]
    public Task<IActionResult> BankDetails() => Execute(async () => Ok(await service.OrderBankDetails(User)));

    [HttpGet("orders/{id:int}")]
    public Task<IActionResult> Summary(int id) => Execute(async () => Ok(await service.OrderPaymentSummary(User, id)));
    [HttpPost("orders/{id:int}/receipts")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public Task<IActionResult> Submit(int id, [FromForm] SubmitPackageReceiptDto dto) => Execute(async () => {
        await service.SubmitOrderReceipt(User, id, dto); return Ok();
    });
    [Authorize(Roles = "ADMIN")]
    [HttpGet("pending")]
    public Task<IActionResult> Pending() => Execute(async () => Ok(await service.PendingOrderReceipts(User)));
    [HttpGet("receipts/{id:int}")]
    public Task<IActionResult> Receipt(int id) => Execute(async () => {
        var file = await service.OrderReceipt(User, id);
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        return File(file.Bytes, file.Type);
    });
    [Authorize(Roles = "ADMIN")]
    [HttpPost("receipts/{id:int}/{decision}")]
    public Task<IActionResult> Review(int id, string decision, ReviewPackageReceiptDto dto) => Execute(async () => {
        if (decision is not ("approve" or "reject")) return BadRequest();
        await service.ReviewOrderReceipt(User, id, dto, decision == "approve"); return Ok();
    });
    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action) {
        try { return await action(); }
        catch (BadHttpRequestException e) { return StatusCode(e.StatusCode, new { message = e.Message }); }
        catch (DbUpdateConcurrencyException) { return Conflict(new { message = "Order changed. Refresh and try again." }); }
        catch (DbUpdateException e) when (e.InnerException is PostgresException p && p.SqlState is "23505" or "40001") {
            return Conflict(new { message = "Receipt already submitted or changed. Refresh and try again." });
        }
        catch (PostgresException e) when (e.SqlState is "40001" or "40P01") {
            return Conflict(new { message = "Order changed. Refresh and retry." });
        }
    }
}
