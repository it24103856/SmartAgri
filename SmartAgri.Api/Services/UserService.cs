using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

/// <summary>
/// Service managing system users, administrative lifecycle operations, role assignments, and metrics.
/// </summary>
public class UserService : IUserService
{
    private readonly ApplicationDbContext _context;

    private static readonly HashSet<string> ValidRoles = new(StringComparer.OrdinalIgnoreCase)
    {
        "ADMIN", "FARMER", "CUSTOMER"
    };

    public UserService(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Retrieves all user records sorted by newest registration date.
    /// </summary>
    public async Task<IEnumerable<UserResponseDto>> GetAllUsersAsync()
    {
        return await _context.Users
            .OrderByDescending(u => u.CreatedAt)
            .Select(u => MapToResponseDto(u))
            .ToListAsync();
    }

    /// <summary>
    /// Looks up a single user by primary key ID.
    /// </summary>
    public async Task<UserResponseDto?> GetUserByIdAsync(int id)
    {
        var user = await _context.Users.FindAsync(id);
        return user == null ? null : MapToResponseDto(user);
    }

    /// <summary>
    /// Creates a new user with password hashing and initial active status.
    /// </summary>
    public async Task<UserResponseDto> CreateUserAsync(CreateUserDto dto)
    {
        if (await _context.Users.AnyAsync(u => u.Email == dto.Email))
        {
            throw new InvalidOperationException("Email is already registered.");
        }

        string passwordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password);

        var user = new User
        {
            FullName = dto.FullName,
            Email = dto.Email,
            Phone = dto.Phone,
            PasswordHash = passwordHash,
            Role = dto.Role.ToUpper(),
            Status = "ACTIVE",
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return MapToResponseDto(user);
    }

    /// <summary>
    /// Updates general profile attributes of an existing user.
    /// </summary>
    public async Task<UserResponseDto?> UpdateUserAsync(int id, UpdateUserDto dto)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return null;

        user.FullName = dto.FullName;
        user.Email = dto.Email;
        user.Phone = dto.Phone;
        user.UpdatedAt = DateTime.UtcNow;

        _context.Users.Update(user);
        await _context.SaveChangesAsync();

        return MapToResponseDto(user);
    }

    /// <summary>
    /// Deletes a user record permanently by primary key ID.
    /// </summary>
    public async Task<bool> DeleteUserAsync(int id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return false;

        _context.Users.Remove(user);
        await _context.SaveChangesAsync();
        return true;
    }

    /// <summary>
    /// Updates the active/inactive/blocked account status of a specified user.
    /// </summary>
    public async Task<bool> ChangeStatusAsync(int id, string newStatus)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null) return false;

        user.Status = newStatus.ToUpper();
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    // NEW
    /// <summary>
    /// Reassigns an authorized role to a user after checking allowed role whitelist.
    /// </summary>
    public async Task<UserResponseDto?> ChangeRoleAsync(int id, string newRole)
    {
        var normalizedRole = newRole?.ToUpper() ?? "";
        if (!ValidRoles.Contains(normalizedRole))
        {
            throw new BadHttpRequestException("Invalid role. Must be ADMIN, FARMER, or CUSTOMER.");
        }

        var user = await _context.Users.FindAsync(id);
        if (user == null) return null;

        user.Role = normalizedRole;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return MapToResponseDto(user);
    }

    // NEW
    /// <summary>
    /// Computes aggregated user statistics broken down by role and account status.
    /// </summary>
    public async Task<UserStatsDto> GetStatsAsync()
    {
        var users = await _context.Users.ToListAsync();

        return new UserStatsDto
        {
            TotalUsers = users.Count,
            TotalAdmins = users.Count(u => u.Role == "ADMIN"),
            TotalFarmers = users.Count(u => u.Role == "FARMER"),
            TotalCustomers = users.Count(u => u.Role == "CUSTOMER"),
            ActiveUsers = users.Count(u => u.Status == "ACTIVE"),
            InactiveUsers = users.Count(u => u.Status == "INACTIVE"),
            BlockedUsers = users.Count(u => u.Status == "BLOCKED"),
        };
    }

    /// <summary>
    /// Projects a User entity onto a UserResponseDto transfer object.
    /// </summary>
    private static UserResponseDto MapToResponseDto(User user)
    {
        return new UserResponseDto
        {
            Id = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            ProfileImageUrl = user.ProfileImageUrl,
        Phone = user.Phone,
        Address = user.Address,
        City = user.City,
        Province = user.Province,
            Role = user.Role,
            Status = user.Status,
            CreatedAt = user.CreatedAt,
            UpdatedAt = user.UpdatedAt
        };
    }
}