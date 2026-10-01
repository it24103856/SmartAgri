namespace SmartAgri.Api.Models;

public class FarmAiAnalysis
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid RequestId { get; set; }

    public int FarmerId { get; set; }

    // Nullable relationship: preserve history if the farm is deleted.
    public int? FarmId { get; set; }

    // Original farm ID retained for historical records.
    public int SourceFarmId { get; set; }

    public string FarmName { get; set; } = string.Empty;

    public string Objective { get; set; } = string.Empty;

    public string Status { get; set; } = "PROCESSING";

    public string RequestJson { get; set; } = "{}";

    public string InputJson { get; set; } = "{}";

    public string? ResultJson { get; set; }

    public string? ErrorCode { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? CompletedAt { get; set; }
}