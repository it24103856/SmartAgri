namespace SmartAgri.Api.Models;

public class AIRequest
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string RequestType { get; set; } = string.Empty;
    public string InputJson { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
