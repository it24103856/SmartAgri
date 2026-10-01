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
[Route("api/farmer-profile")]
[Authorize(Roles = "FARMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
public sealed class FarmerProfileController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly ProfileImageStore _images;

    public FarmerProfileController(
        ApplicationDbContext db,
        ProfileImageStore images)
    {
        _db = db;
        _images = images;
    }

    private async Task<User?> CurrentFarmerAsync()
    {
        if (!int.TryParse(
                User.FindFirstValue(ClaimTypes.NameIdentifier),
                out var id))
        {
            return null;
        }

        return await _db.Users.SingleOrDefaultAsync(user =>
            user.Id == id &&
            user.Role == "FARMER" &&
            user.Status == "ACTIVE");
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
        var farmer = await CurrentFarmerAsync();

        if (farmer is null)
            return Forbid();

        return Ok(ToDto(farmer));
    }

    [HttpPut]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<IActionResult> Update(
        [FromForm] UpdateFarmerProfileDto dto)
    {
        var farmer = await CurrentFarmerAsync();

        if (farmer is null)
            return Forbid();

        var newPhotos = new List<string>();

        if (dto.Photo is not null)
        {
            try
            {
                newPhotos = await _images.SaveAsync(
                    new[] { dto.Photo });
            }
            catch (BadHttpRequestException exception)
            {
                return BadRequest(new
                {
                    message = exception.Message
                });
            }
        }

        var oldPhoto = farmer.ProfileImageUrl;

        try
        {
            farmer.FullName = dto.FullName.Trim();
            farmer.Phone = dto.Phone.Trim();
            farmer.Address = dto.Address.Trim();
            farmer.City = dto.City.Trim();
            farmer.Province = dto.Province.Trim();
            farmer.UpdatedAt = DateTime.UtcNow;

            if (newPhotos.Count > 0)
            {
                farmer.ProfileImageUrl = newPhotos[0];
            }

            await _db.SaveChangesAsync();
        }
        catch
        {
            _images.DeleteFiles(newPhotos);
            throw;
        }

        if (newPhotos.Count > 0 &&
            !string.IsNullOrWhiteSpace(oldPhoto))
        {
            _images.DeleteFiles(new[] { oldPhoto });
        }

        return Ok(ToDto(farmer));
    }
}