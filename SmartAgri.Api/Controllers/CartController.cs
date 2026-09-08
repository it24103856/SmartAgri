using Microsoft.AspNetCore.Mvc;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CartController : ControllerBase
{
    [HttpGet]
    public IActionResult GetCart() => Ok(new { message = "Cart endpoint ready" });

    [HttpPost("items")]
    public IActionResult AddItem() => Ok(new { message = "Item added to cart" });
}
