using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AIController : ControllerBase
{
    [HttpPost("analyze-farm")]
    public IActionResult AnalyzeFarm() => Ok(new { message = "AI farm analysis endpoint ready" });

    [HttpPost("recommendations")]
    public IActionResult GetRecommendations() => Ok(new { message = "AI recommendations endpoint ready" });
}
