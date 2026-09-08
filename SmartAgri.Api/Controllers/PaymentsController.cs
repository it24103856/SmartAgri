using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentsController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Payments endpoint ready" });

    [HttpPost]
    public IActionResult CreatePayment() => Ok(new { message = "Payment submitted" });
}
