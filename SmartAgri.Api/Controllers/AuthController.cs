using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    // POST: api/auth/register
    // Public endpoint — anyone can call this. Role is restricted server-side
    // in AuthService (only CUSTOMER/FARMER allowed here).
    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<UserDto>> Register([FromBody] RegisterDto dto)
    {
        try
        {
            var user = await _authService.RegisterAsync(dto);
            return CreatedAtAction(nameof(Register), new { id = user.Id }, user);
        }
        catch (BadHttpRequestException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("register-with-photo")]
    [AllowAnonymous]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<ActionResult<UserDto>> RegisterWithPhoto(
        [FromForm] RegisterWithPhotoDto dto, [FromServices] ProfileImageStore images)
    {
        var urls = dto.Photo is null ? new List<string>() : await images.SaveAsync(new[] { dto.Photo });
        try
        {
            var user = await _authService.RegisterAsync(dto, urls.FirstOrDefault());
            return CreatedAtAction(nameof(Register), new { id = user.Id }, user);
        }
        catch
        {
            images.DeleteFiles(urls);
            throw;
        }
    }

    [HttpPut("profile-photo")]
    [Authorize]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<IActionResult> UpdateProfilePhoto(
        [FromForm] ProfilePhotoDto dto,
        [FromServices] ApplicationDbContext db,
        [FromServices] ProfileImageStore images)
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) return Unauthorized();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == id);
        if (user is null) return Unauthorized();
        if (user.Status != "ACTIVE") return Forbid();
        var urls = await images.SaveAsync(new[] { dto.Photo });
        var oldUrl = user.ProfileImageUrl;
        try
        {
            user.ProfileImageUrl = urls[0];
            user.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }
        catch
        {
            images.DeleteFiles(urls);
            throw;
        }
        if (oldUrl is not null) images.DeleteFiles(new[] { oldUrl });
        return Ok(new { profileImageUrl = user.ProfileImageUrl });
    }

    // POST: api/auth/login
    // Public endpoint — returns a JWT token + user info on success.
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginDto dto)
    {
        try
        {
            var result = await _authService.LoginAsync(dto);
            if (result == null)
                return Unauthorized(new { message = "Invalid email or password." });

            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            // thrown by AuthService when account Status != ACTIVE
            return StatusCode(403, new { message = ex.Message });
        }
    }

    // GET: api/auth/me
    // Any authenticated user (regardless of role) can call this to check
    // that their token is valid and see their own claims.
    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value;
        var role = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;

        return Ok(new { userId, email, role });
    }

    // GET: api/auth/admin-check
    // EXAMPLE ONLY — shows how a route becomes "admin dashboard only".
    // Add [Authorize(Roles = "ADMIN")] on any controller/action to restrict it.
    // If the token is missing/invalid -> 401 Unauthorized.
    // If the token is valid but role != ADMIN -> 403 Forbidden.
    [HttpGet("admin-check")]
    [Authorize(Roles = "ADMIN")]
    public IActionResult AdminCheck()
    {
        return Ok(new { message = "Token valid and role is ADMIN — access granted." });
    }
}