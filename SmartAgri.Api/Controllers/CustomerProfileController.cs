using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/customer-profile")]
[Authorize(Roles = "CUSTOMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class CustomerProfileController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly ProfileImageStore _images;

    public CustomerProfileController(
        ApplicationDbContext db,
        ProfileImageStore images)
    {
        _db = db;
        _images = images;
    }

    private async Task<User?> CurrentUser()
    {
        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            return null;
        }

        return await _db.Users.SingleOrDefaultAsync(u =>
            u.Id == id &&
            u.Role == "CUSTOMER" &&
            u.Status == "ACTIVE");
    }

    private static UserDto ToDto(User user) => new()
    {
        Id = user.Id,
        FullName = user.FullName,
        Email = user.Email,
        Phone = user.Phone,
        Address = user.Address,
        City = user.City,
        Province = user.Province,
        ProfileImageUrl = user.ProfileImageUrl,
        Role = user.Role,
        Status = user.Status,
        CreatedAt = user.CreatedAt
    };

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var user = await CurrentUser();

        if (user is null)
            return Forbid();

        return Ok(ToDto(user));
    }

    [HttpPut]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<IActionResult> Update(
        [FromForm] UpdateCustomerProfileDto dto)
    {
        var user = await CurrentUser();

        if (user is null)
            return Forbid();

        var newPhotos = dto.Photo is null
            ? new List<string>()
            : await _images.SaveAsync(new[] { dto.Photo });

        var oldPhoto = user.ProfileImageUrl;

        try
        {
            user.FullName = dto.FullName.Trim();
            user.Phone = dto.Phone.Trim();
            user.Address = dto.Address.Trim();
            user.City = dto.City.Trim();
            user.Province = dto.Province.Trim();
            user.UpdatedAt = DateTime.UtcNow;

            if (newPhotos.Count > 0)
                user.ProfileImageUrl = newPhotos[0];

            await _db.SaveChangesAsync();
        }
        catch
        {
            _images.DeleteFiles(newPhotos);
            throw;
        }

        if (newPhotos.Count > 0 && oldPhoto is not null)
            _images.DeleteFiles(new[] { oldPhoto });

        return Ok(ToDto(user));
    }
}