using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class AdminSmartBasketService
{
    private readonly ApplicationDbContext _db;

    public AdminSmartBasketService(ApplicationDbContext db)
    {
        _db = db;
    }

    private async Task RequireAdmin(int adminId, CancellationToken ct)
    {
        var allowed = await _db.Users.AnyAsync(
            user => user.Id == adminId &&
                user.Role == "ADMIN" &&
                user.Status == "ACTIVE",
            ct);

        if (!allowed)
        {
            throw new BadHttpRequestException(
                "An active admin account is required.", 403);
        }
    }

    public async Task<object> List(
        int adminId,
        int page,
        int pageSize,
        CancellationToken ct)
    {
        await RequireAdmin(adminId, ct);

        if (page < 1 || page > 10000 ||
            pageSize < 1 || pageSize > 50)
        {
            throw new BadHttpRequestException(
                "Invalid pagination.", 400);
        }

        var query = _db.SmartBasketWorkflows
            .AsNoTracking()
            .Where(workflow =>
                workflow.Status == SmartBasketStatus.AwaitingApproval);

        var totalCount = await query.CountAsync(ct);

        var items = await query
            .OrderBy(workflow => workflow.UpdatedAt)
            .ThenBy(workflow => workflow.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(workflow => new
            {
                workflow.Id,
                workflow.CustomerId,
                workflow.Objective,
                workflow.Budget,
                workflow.Currency,
                workflow.Status,
                workflow.ProposedTotal,
                workflow.ProposalRevision,
                workflow.Version,
                workflow.UpdatedAt
            })
            .ToListAsync(ct);

        return new { items, totalCount, page, pageSize };
    }

    public async Task<object> Get(
        int adminId,
        Guid id,
        CancellationToken ct)
    {
        await RequireAdmin(adminId, ct);

        var workflow = await _db.SmartBasketWorkflows
            .AsNoTracking()
            .SingleOrDefaultAsync(value => value.Id == id, ct)
            ?? throw new BadHttpRequestException(
                "Smart Basket request not found.", 404);

        var items = await _db.SmartBasketItems
            .AsNoTracking()
            .Where(item =>
                item.WorkflowId == id &&
                item.ProposalRevision == workflow.ProposalRevision)
            .OrderBy(item => item.Id)
            .Select(item => new
            {
                item.ProductId,
                item.ProductName,
                item.Unit,
                item.Quantity,
                item.UnitPrice,
                lineTotal = item.Quantity * item.UnitPrice
            })
            .ToListAsync(ct);

        var history = await _db.SmartBasketSteps
            .AsNoTracking()
            .Where(step => step.WorkflowId == id)
            .OrderBy(step => step.Attempt)
            .ThenBy(step => step.Sequence)
            .Select(step => new
            {
                step.Attempt,
                step.Sequence,
                step.AgentName,
                step.ToolName,
                step.Status,
                step.StartedAt,
                step.FinishedAt
            })
            .ToListAsync(ct);

        var decisions = await _db.SmartBasketApprovals
            .AsNoTracking()
            .Where(approval => approval.WorkflowId == id)
            .OrderBy(approval => approval.CreatedAt)
            .Select(approval => new
            {
                approval.ProposalRevision,
                approval.AdminId,
                approval.Decision,
                approval.Note,
                approval.CreatedAt
            })
            .ToListAsync(ct);

        var linkedOrder = await _db.CustomerOrders
            .AsNoTracking()
            .Where(order => order.SmartBasketWorkflowId == id)
            .Select(order => new
            {
                order.Id,
                order.Status,
                order.TotalAmount,
                paymentStatus = order.Payment.Status
            })
            .SingleOrDefaultAsync(ct);

        return new
        {
            workflow.Id,
            workflow.CustomerId,
            workflow.Objective,
            workflow.Budget,
            workflow.Currency,
            workflow.Status,
            workflow.ProposedTotal,
            workflow.ProposalRevision,
            workflow.Version,
            workflow.CreatedAt,
            workflow.UpdatedAt,
            linkedOrder,
            items,
            history,
            decisions
        };
    }

    public async Task Decide(
        int adminId,
        Guid id,
        SmartBasketDecisionRequest request,
        CancellationToken ct)
    {
        await RequireAdmin(adminId, ct);

        var note = request.Note?.Trim();

        if (request.Version == Guid.Empty ||
            request.ProposalRevision < 1 ||
            (request.Decision != "Approved" &&
             request.Decision != "Rejected") ||
            (note?.Length ?? 0) > 1000 ||
            (request.Decision == "Rejected" &&
             string.IsNullOrWhiteSpace(note)))
        {
            throw new BadHttpRequestException(
                "Invalid approval decision.", 400);
        }

        await using var transaction =
            await _db.Database.BeginTransactionAsync(ct);

        // Lock the workflow while checking and recording the decision.
        var matches = await _db.SmartBasketWorkflows
            .FromSqlInterpolated($"""
                SELECT * FROM "SmartBasketWorkflows"
                WHERE "Id" = {id}
                FOR UPDATE
                """)
            .ToListAsync(ct);

        var workflow = matches.SingleOrDefault()
            ?? throw new BadHttpRequestException(
                "Smart Basket request not found.", 404);

        if (workflow.Version != request.Version ||
            workflow.ProposalRevision != request.ProposalRevision)
        {
            throw new BadHttpRequestException(
                "The basket changed. Reload it before deciding.", 409);
        }

        if (workflow.Status != SmartBasketStatus.AwaitingApproval)
        {
            throw new BadHttpRequestException(
                "This basket is not awaiting approval.", 409);
        }

        var alreadyDecided = await _db.SmartBasketApprovals.AnyAsync(
            approval => approval.WorkflowId == id &&
                approval.ProposalRevision == request.ProposalRevision,
            ct);

        if (alreadyDecided)
        {
            throw new BadHttpRequestException(
                "This revision already has a decision.", 409);
        }

        if (request.Decision == "Approved")
        {
            await CheckApprovalEligibility(workflow, ct);
        }

        var now = DateTime.UtcNow;

        _db.SmartBasketApprovals.Add(new SmartBasketApproval
        {
            WorkflowId = id,
            ProposalRevision = workflow.ProposalRevision,
            AdminId = adminId,
            Decision = request.Decision,
            Note = string.IsNullOrWhiteSpace(note) ? null : note,
            CreatedAt = now
        });

        workflow.Status = request.Decision == "Approved"
            ? SmartBasketStatus.Approved
            : SmartBasketStatus.Rejected;

        workflow.Version = Guid.NewGuid();
        workflow.UpdatedAt = now;

        // Approval still needs checkout; rejection ends this request.
        workflow.CompletedAt = request.Decision == "Rejected"
            ? now
            : null;

        var lastSequence = await _db.SmartBasketSteps
            .Where(step =>
                step.WorkflowId == id &&
                step.Attempt == workflow.AttemptCount)
            .MaxAsync(step => (int?)step.Sequence, ct) ?? -1;

        _db.SmartBasketSteps.Add(new SmartBasketStep
        {
            WorkflowId = id,
            Attempt = workflow.AttemptCount,
            Sequence = lastSequence + 1,
            AgentName = "Admin",
            ToolName = "review_proposal",
            Status = "Completed",
            StartedAt = now,
            FinishedAt = now,
            OutputJson = JsonSerializer.Serialize(new
            {
                adminId,
                revision = workflow.ProposalRevision,
                decision = request.Decision
            })
        });

        try
        {
            await _db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new BadHttpRequestException(
                "The basket changed. Reload it and try again.", 409);
        }
    }

    private async Task CheckApprovalEligibility(
        SmartBasketWorkflow workflow,
        CancellationToken ct)
    {
        var customerActive = await _db.Users.AnyAsync(
            user => user.Id == workflow.CustomerId &&
                user.Role == "CUSTOMER" &&
                user.Status == "ACTIVE",
            ct);

        if (!customerActive)
        {
            throw new BadHttpRequestException(
                "The customer account is no longer active.", 409);
        }

        using var constraints = JsonDocument.Parse(
            workflow.ConstraintsJson);

        if (!constraints.RootElement.TryGetProperty(
                "categoryId", out var category) ||
            !category.TryGetInt32(out var categoryId) ||
            categoryId <= 0)
        {
            throw new BadHttpRequestException(
                "The basket has no valid category.", 409);
        }

        var excludedIds = new HashSet<int>();

        if (constraints.RootElement.TryGetProperty(
                "excludedProductIds", out var exclusions))
        {
            foreach (var value in exclusions.EnumerateArray())
                excludedIds.Add(value.GetInt32());
        }

        var items = await _db.SmartBasketItems
            .AsNoTracking()
            .Where(item =>
                item.WorkflowId == workflow.Id &&
                item.ProposalRevision == workflow.ProposalRevision)
            .ToListAsync(ct);

        if (items.Count == 0)
        {
            throw new BadHttpRequestException(
                "An empty basket cannot be approved.", 409);
        }

        var ids = items.Select(item => item.ProductId).ToArray();

        var products = await _db.Products
            .AsNoTracking()
            .Where(product => ids.Contains(product.Id))
            .ToDictionaryAsync(product => product.Id, ct);

        decimal total = 0;

        foreach (var item in items)
        {
            if (!products.TryGetValue(item.ProductId, out var product) ||
                !product.IsFood ||
                product.Status != "APPROVED" ||
                product.CategoryId != categoryId ||
                excludedIds.Contains(product.Id) ||
                item.Quantity <= 0 ||
                product.StockQuantity < item.Quantity ||
                product.Price <= 0 ||
                product.Price != item.UnitPrice ||
                product.Unit != item.Unit ||
                product.Name != item.ProductName)
            {
                throw new BadHttpRequestException(
                    "Product details, price or availability changed. " +
                    "Reject this proposal and ask for a new one.",
                    409);
            }

            total += product.Price * item.Quantity;
        }

        if (workflow.Currency != "LKR" ||
            total <= 0 ||
            total > workflow.Budget ||
            total != workflow.ProposedTotal)
        {
            throw new BadHttpRequestException(
                "The proposal total is invalid.", 409);
        }
    }
}