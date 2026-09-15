using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/customer-orders")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class CustomerOrderCancellationController : ControllerBase
{
    private readonly CustomerCheckoutService _checkout;
    private readonly CustomerOrderCancellationService _cancellation;

    public CustomerOrderCancellationController(
        CustomerCheckoutService checkout,
        CustomerOrderCancellationService cancellation)
    {
        _checkout = checkout;
        _cancellation = cancellation;
    }

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(
        int id,
        [FromBody] CancelCustomerOrderRequest request,
        CancellationToken ct)
    {
        var userId = await _checkout.CustomerId(User);

        await _cancellation.Cancel(
            userId,
            id,
            request.Reason,
            ct);

        return Ok(new
        {
            orderId = id,
            status = "Cancelled",
            message = "Order cancelled."
        });
    }
}