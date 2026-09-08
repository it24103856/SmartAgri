using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Payment endpoint ready" });

    [HttpPost]
    public IActionResult CreatePayment() => Ok(new { message = "Payment created" });
}
