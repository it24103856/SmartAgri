using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/customer-payments")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class CustomerPaymentsController : ControllerBase
{
    private readonly CustomerCheckoutService _service;

    public CustomerPaymentsController(CustomerCheckoutService service)
    {
        _service = service;
    }

    [HttpPost("{orderId:int}/session")]
    public async Task<IActionResult> Session(int orderId)
    {
        var userId = await _service.CustomerId(User);
        var url = await _service.PaymentUrl(userId, orderId);

        return Ok(new { url });
    }

    [AllowAnonymous]
    [HttpGet("checkout")]
    public async Task<IActionResult> Checkout([FromQuery] string token)
    {
        Response.Headers["Referrer-Policy"] = "origin";
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        Response.Headers["Content-Security-Policy"] =
            "default-src 'none'; form-action https://sandbox.payhere.lk";

        return Content(
            await _service.CheckoutHtml(token),
            "text/html; charset=utf-8");
    }

    [AllowAnonymous]
    [HttpPost("notify")]
    public async Task<IActionResult> Notify()
    {
        if (!Request.HasFormContentType)
            return BadRequest(new { message = "Form data required." });

        await _service.Notify(await Request.ReadFormAsync());
        return Ok();
    }

    [AllowAnonymous]
    [HttpGet("return")]
    public ContentResult Return()
    {
        return Content(
            """
            <!doctype html>
            <html>
            <head>
              <meta name="viewport"
                    content="width=device-width,initial-scale=1">
              <title>Return to SmartAgri</title>
            </head>
            <body>
              <h2>Return to SmartAgri</h2>
              <p>Open the SmartAgri app and tap Check payment status.</p>
              <p>Your app will display the verified payment result.</p>
            </body>
            </html>
            """,
            "text/html; charset=utf-8");
    }
}