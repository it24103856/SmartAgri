using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Customers endpoint ready" });

    [HttpGet("{id}")]
    public IActionResult GetById(int id) => Ok(new { id, message = "Customer found" });
}
