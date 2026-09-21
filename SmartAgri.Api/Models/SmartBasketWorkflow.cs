using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartAgri.Api.Models;

public static class SmartBasketStatus
{
    public const string Pending = "Pending";
    public const string Planning = "Planning";
    public const string Validating = "Validating";
    public const string AwaitingCustomerReview = "AwaitingCustomerReview";
    public const string AwaitingApproval = "AwaitingApproval";
    public const string Approved = "Approved";
    public const string Rejected = "Rejected";
    public const string Failed = "Failed";
    public const string Ordered = "Ordered";
    public const string Deleted = "Deleted";
}

public sealed class SmartBasketWorkflow
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public int CustomerId { get; set; }

    // Used to recognize a retry of the same submission.
    public Guid RequestId { get; set; }

    [MaxLength(64)]
    public string RequestHash { get; set; } = "";

    [MaxLength(1000)]
    public string Objective { get; set; } = "";

    [Column(TypeName = "numeric(18,2)")]
    public decimal Budget { get; set; }

    [MaxLength(3)]
    public string Currency { get; set; } = "LKR";

    // Structured exclusions such as product/category IDs.
    [Column(TypeName = "jsonb")]
    public string ConstraintsJson { get; set; } = "{}";

    [MaxLength(30)]
    public string Status { get; set; } = SmartBasketStatus.Pending;

    // Structured multi-step plan.
    [Column(TypeName = "jsonb")]
    public string PlanJson { get; set; } = "{}";

    [Column(TypeName = "jsonb")]
    public string ValidationJson { get; set; } = "{}";

    [Column(TypeName = "numeric(18,2)")]
    public decimal ProposedTotal { get; set; }

    // Approval must refer to this exact proposal revision.
    public int ProposalRevision { get; set; }

    [MaxLength(2000)]
    public string? FailureReason { get; set; }

    // Supports bounded retries and recovery after worker interruption.
    public int AttemptCount { get; set; }

    [MaxLength(100)]
    public string? LeaseOwner { get; set; }

    public DateTime? LeaseExpiresAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }

    public Guid Version { get; set; } = Guid.NewGuid();

    public List<SmartBasketItem> Items { get; set; } = new();
    public List<SmartBasketStep> Steps { get; set; } = new();
    public List<SmartBasketApproval> Approvals { get; set; } = new();
}

public sealed class SmartBasketItem
{
    public int Id { get; set; }

    public Guid WorkflowId { get; set; }
    public int ProposalRevision { get; set; }

    public int ProductId { get; set; }

    // Snapshot of the product when the proposal was generated.
    [MaxLength(150)]
    public string ProductName { get; set; } = "";

    [MaxLength(20)]
    public string Unit { get; set; } = "";

    public int Quantity { get; set; }

    [Column(TypeName = "numeric(18,2)")]
    public decimal UnitPrice { get; set; }

    [NotMapped]
    public decimal LineTotal => Quantity * UnitPrice;
}

public sealed class SmartBasketStep
{
    public long Id { get; set; }

    public Guid WorkflowId { get; set; }

    public int Attempt { get; set; }
    public int Sequence { get; set; }

    [MaxLength(80)]
    public string AgentName { get; set; } = "";

    [MaxLength(100)]
    public string? ToolName { get; set; }

    [MaxLength(30)]
    public string Status { get; set; } = "Started";

    // Store sanitized structured summaries, not secrets or hidden reasoning.
    [Column(TypeName = "jsonb")]
    public string InputJson { get; set; } = "{}";

    [Column(TypeName = "jsonb")]
    public string OutputJson { get; set; } = "{}";

    [MaxLength(2000)]
    public string? ErrorMessage { get; set; }

    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? FinishedAt { get; set; }
}

public sealed class SmartBasketApproval
{
    public long Id { get; set; }

    public Guid WorkflowId { get; set; }

    public int ProposalRevision { get; set; }

    public int AdminId { get; set; }

    // Approved, Rejected or RevisionRequested.
    [MaxLength(30)]
    public string Decision { get; set; } = "";

    [MaxLength(1000)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
