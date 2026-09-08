using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FarmerController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Farmer endpoint ready" });

    [HttpGet("{id}")]
    public IActionResult GetById(int id) => Ok(new { id, message = "Farmer found" });
}
