using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll() => Ok(new { message = "Product endpoint ready" });

    [HttpGet("{id}")]
    public IActionResult GetById(int id) => Ok(new { id, message = "Product found" });
}
