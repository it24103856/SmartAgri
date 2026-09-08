using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    [HttpGet("dashboard")]
    public IActionResult Dashboard() => Ok(new { message = "Admin dashboard ready" });

    [HttpGet("users")]
    public IActionResult Users() => Ok(new { message = "Admin users endpoint ready" });
}
