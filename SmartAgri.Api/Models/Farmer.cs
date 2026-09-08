namespace SmartAgri.Api.Models;

public class Farmer
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string FarmName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public string? Address { get; set; }
    public string? Specialization { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
