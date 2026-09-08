using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EquipmentController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Equipment endpoint ready" });

    [HttpGet("{id}")]
    public IActionResult GetById(int id) => Ok(new { id, message = "Equipment found" });
}
