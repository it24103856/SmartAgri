using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FarmsController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Farms endpoint ready" });

    [HttpGet("{id}")]
    public IActionResult GetById(int id) => Ok(new { id, message = "Farm found" });
}
