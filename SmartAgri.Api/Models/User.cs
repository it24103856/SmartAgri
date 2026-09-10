namespace SmartAgri.Api.Models;

public class User
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? ProfileImageUrl { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? Province { get; set; }
    public string PasswordHash { get; set; } = string.Empty;
    
    // Roles: ADMIN, FARMER, CUSTOMER
    public string Role { get; set; } = "CUSTOMER";
    
    // Status: ACTIVE, INACTIVE, BLOCKED
    public string Status { get; set; } = "ACTIVE";
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}