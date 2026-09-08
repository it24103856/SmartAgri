namespace SmartAgri.Api.Models;

public class Recommendation
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Details { get; set; } = string.Empty;
    public decimal Score { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
