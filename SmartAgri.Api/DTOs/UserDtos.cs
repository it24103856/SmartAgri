using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public class LoginDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class RegisterDto
{
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    [Required, RegularExpression(@"^\+?[0-9][0-9 ()-]{5,23}[0-9]$", ErrorMessage = "Enter a valid telephone number.")]
    public string Phone { get; set; } = string.Empty;
    [Required, StringLength(250)]
    public string Address { get; set; } = string.Empty;
    [Required, StringLength(100)]
    public string City { get; set; } = string.Empty;
    [Required, StringLength(100)]
    public string Province { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Role { get; set; } = "CUSTOMER";
}

public class UserDto
{
    public string? ProfileImageUrl { get; set; }
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? Province { get; set; }
    public string Role { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class UserResponseDto
{
    public string? ProfileImageUrl { get; set; }
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? Province { get; set; }
    public string Role { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class CreateUserDto
{
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string Password { get; set; } = string.Empty;
    public string Role { get; set; } = "CUSTOMER";
}

public class UpdateUserDto
{
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
}

public class AuthResponseDto
{
    public string Token { get; set; } = string.Empty;
    public UserDto User { get; set; } = null!;
}

// NEW: role change request body
public class ChangeRoleDto
{
    public string Role { get; set; } = string.Empty; // ADMIN | FARMER | CUSTOMER
}

// NEW: summary counts for the Stats Cards on the User Management page
public class UserStatsDto
{
    public int TotalUsers { get; set; }
    public int TotalAdmins { get; set; }
    public int TotalFarmers { get; set; }
    public int TotalCustomers { get; set; }
    public int ActiveUsers { get; set; }
    public int InactiveUsers { get; set; }
    public int BlockedUsers { get; set; }
}
public class RegisterWithPhotoDto : RegisterDto
{
    public IFormFile? Photo { get; set; }
}

public class ProfilePhotoDto
{
    [Required]
    public IFormFile Photo { get; set; } = null!;
}
