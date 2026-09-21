using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class SmartBasketService
{
    private readonly ApplicationDbContext _db;

    public SmartBasketService(ApplicationDbContext db)
    {
        _db = db;
    }

    public async Task RequireCustomer(
        int customerId,
        CancellationToken ct)
    {
        var allowed = await _db.Users.AnyAsync(
            user => user.Id == customerId
                && user.Role == "CUSTOMER"
                && user.Status == "ACTIVE",
            ct);

        if (!allowed)
        {
            throw new UnauthorizedAccessException(
                "An active customer account is required.");
        }
    }

    public async Task<SmartBasketWorkflow> Create(
        int customerId,
        CreateSmartBasketRequest request,
        CancellationToken ct)
    {
        await RequireCustomer(customerId, ct);


        var objective = request.Objective.Trim();
        if (request.CategoryId is int selectedId && selectedId <= 0)
{
    throw new BadHttpRequestException(
        "Invalid category.",
        400);
}

        // Normalize equivalent budget values such as 3000 and 3000.00.
      var canonical = JsonSerializer.Serialize(new
{
    objective,
    budget = request.Budget.ToString(
        "0.00",
        CultureInfo.InvariantCulture),
    currency = "LKR",
    categoryId = request.CategoryId
});

        var hash = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));

        var existing = await FindRequest(
            customerId,
            request.RequestId,
            ct);

        if (existing is not null)
            return ValidateRetry(existing, hash);

        if (request.CategoryId is int categoryId)
        {
            var categoryExists = await _db.Categories
                .AnyAsync(category => category.Id == categoryId, ct);

            if (!categoryExists)
            {
                throw new BadHttpRequestException(
                    "The selected category does not exist.",
                    400);
            }
        }

        var workflow = new SmartBasketWorkflow
        {
            CustomerId = customerId,
            RequestId = request.RequestId,
            RequestHash = hash,
            Objective = objective,
            Budget = request.Budget,
            Currency = "LKR",
            Status = SmartBasketStatus.Pending,
            ConstraintsJson = JsonSerializer.Serialize(new
{
    categoryId = request.CategoryId,
    excludedProductIds = Array.Empty<int>()
}),
            PlanJson = "{}",
            ValidationJson = "{}",
            ProposedTotal = 0m,
            ProposalRevision = 0,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _db.SmartBasketWorkflows.Add(workflow);

        try
        {
            await _db.SaveChangesAsync(ct);
            return workflow;
        }
        catch (DbUpdateException error)
            when (error.InnerException is PostgresException postgres
                && postgres.SqlState == "23505"
                && postgres.ConstraintName ==
                    "IX_SmartBasketWorkflows_CustomerId_RequestId")
        {
            // Another copy of this same request may have just saved.
            _db.Entry(workflow).State = EntityState.Detached;

            var saved = await FindRequest(
                customerId,
                request.RequestId,
                ct);

            if (saved is null)
                throw;

            return ValidateRetry(saved, hash);
        }
    }

    private Task<SmartBasketWorkflow?> FindRequest(
        int customerId,
        Guid requestId,
        CancellationToken ct)
    {
        return _db.SmartBasketWorkflows
            .AsNoTracking()
            .SingleOrDefaultAsync(
                workflow => workflow.CustomerId == customerId
                    && workflow.RequestId == requestId,
                ct);
    }

    private static SmartBasketWorkflow ValidateRetry(
        SmartBasketWorkflow existing,
        string requestHash)
    {
        if (existing.Status == SmartBasketStatus.Deleted)
        {
            throw new BadHttpRequestException(
                "This basket was deleted. Submit a new request.",
                409);
        }

        if (existing.RequestHash != requestHash)
        {
            throw new BadHttpRequestException(
                "This request ID was already used with different details.",
                409);
        }

        return existing;
    }

    public async Task<object> List(
        int customerId,
        int page,
        int pageSize,
        CancellationToken ct)
    {
        await RequireCustomer(customerId, ct);

        if (page < 1 || page > 10000 ||
            pageSize < 1 || pageSize > 50)
        {
            throw new BadHttpRequestException(
                "Page must be 1–10000 and pageSize must be 1–50.");
        }

        var query = _db.SmartBasketWorkflows
            .AsNoTracking()
            .Where(workflow =>
                workflow.CustomerId == customerId &&
                workflow.Status != SmartBasketStatus.Deleted);

        var totalCount = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(workflow => workflow.CreatedAt)
            .ThenByDescending(workflow => workflow.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(workflow => new
            {
                workflow.Id,
                workflow.Objective,
                workflow.Budget,
                workflow.Currency,
                workflow.Status,
                workflow.ProposedTotal,
                workflow.ProposalRevision,
                workflow.CreatedAt,
                workflow.UpdatedAt,
                canDelete =
                    (
                        workflow.Status == SmartBasketStatus.AwaitingCustomerReview ||
                        workflow.Status == SmartBasketStatus.AwaitingApproval ||
                        workflow.Status == SmartBasketStatus.Approved ||
                        workflow.Status == SmartBasketStatus.Rejected ||
                        workflow.Status == SmartBasketStatus.Failed
                    )
                    && !_db.CustomerOrders.Any(order =>
                        order.SmartBasketWorkflowId == workflow.Id)
            })
            .ToListAsync(ct);

        return new
        {
            items,
            totalCount,
            page,
            pageSize
        };
    }

    public async Task<object> Get(
        int customerId,
        Guid workflowId,
        CancellationToken ct)
    {
        await RequireCustomer(customerId, ct);

        var workflow = await _db.SmartBasketWorkflows
            .AsNoTracking()
            .Include(value => value.Items)
            .SingleOrDefaultAsync(
                value => value.Id == workflowId
                    && value.CustomerId == customerId
                    && value.Status != SmartBasketStatus.Deleted,
                ct)
            ?? throw new BadHttpRequestException(
                "Smart Basket request not found.",
                404);

        var linkedOrder = await _db.CustomerOrders
            .AsNoTracking()
            .Where(order =>
                order.SmartBasketWorkflowId == workflowId &&
                order.UserId == customerId)
            .Select(order => new
            {
                order.Id,
                order.Status,
                order.TotalAmount,
                paymentStatus = order.Payment.Status
            })
            .SingleOrDefaultAsync(ct);

        // Return customer-facing fields only.
        // Internal agent inputs, errors, leases and hashes stay private.
        return new
        {
            workflow.Id,
            workflow.Objective,
            workflow.Budget,
            workflow.Currency,
            workflow.Status,
            workflow.ProposedTotal,
            workflow.ProposalRevision,
            workflow.Version,
            workflow.CreatedAt,
            workflow.UpdatedAt,
            workflow.CompletedAt,
            linkedOrder,

            items = workflow.Items
                .Where(item =>
                    item.ProposalRevision == workflow.ProposalRevision)
                .OrderBy(item => item.Id)
                .Select(item => new
                {
                    item.ProductId,
                    item.ProductName,
                    item.Unit,
                    item.Quantity,
                    item.UnitPrice,
                    item.LineTotal
                })
                .ToArray()
        };
    }


    public async Task Delete(
        int customerId,
        Guid workflowId,
        CancellationToken ct)
    {
        await RequireCustomer(customerId, ct);

        await using var transaction =
            await _db.Database.BeginTransactionAsync(ct);

        // Use the same workflow lock as review and checkout.
        var matches = await _db.SmartBasketWorkflows
            .FromSqlInterpolated($"""
                SELECT * FROM "SmartBasketWorkflows"
                WHERE "Id" = {workflowId}
                  AND "CustomerId" = {customerId}
                FOR UPDATE
                """)
            .ToListAsync(ct);

        var workflow = matches.SingleOrDefault()
            ?? throw new BadHttpRequestException(
                "Smart Basket request not found.", 404);

        var hasOrder = await _db.CustomerOrders
            .AnyAsync(
                order => order.SmartBasketWorkflowId == workflowId,
                ct);

        if (hasOrder || workflow.Status == SmartBasketStatus.Ordered)
        {
            throw new BadHttpRequestException(
                "This basket is linked to an order and cannot be deleted.",
                409);
        }

        // Safe retry if the first response was lost.
        if (workflow.Status == SmartBasketStatus.Deleted)
        {
            await transaction.CommitAsync(ct);
            return;
        }

        var canDelete =
            workflow.Status == SmartBasketStatus.AwaitingCustomerReview ||
            workflow.Status == SmartBasketStatus.AwaitingApproval ||
            workflow.Status == SmartBasketStatus.Approved ||
            workflow.Status == SmartBasketStatus.Rejected ||
            workflow.Status == SmartBasketStatus.Failed;

        if (!canDelete)
        {
            throw new BadHttpRequestException(
                "This basket is still being prepared. Try again when it finishes.",
                409);
        }

        var previousStatus = workflow.Status;
        var now = DateTime.UtcNow;

        workflow.Status = SmartBasketStatus.Deleted;
        workflow.Version = Guid.NewGuid();
        workflow.UpdatedAt = now;
        workflow.CompletedAt ??= now;

        var lastSequence = await _db.SmartBasketSteps
            .Where(step =>
                step.WorkflowId == workflowId &&
                step.Attempt == workflow.AttemptCount)
            .MaxAsync(step => (int?)step.Sequence, ct) ?? -1;

        _db.SmartBasketSteps.Add(new SmartBasketStep
        {
            WorkflowId = workflowId,
            Attempt = workflow.AttemptCount,
            Sequence = lastSequence + 1,
            AgentName = "Customer",
            ToolName = "delete_basket",
            Status = "Completed",
            StartedAt = now,
            FinishedAt = now,
            InputJson = JsonSerializer.Serialize(new
            {
                customerId,
                previousStatus
            }),
            OutputJson = JsonSerializer.Serialize(new
            {
                status = SmartBasketStatus.Deleted
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
                "This basket changed. Refresh history and try again.",
                409);
        }
    }

    public async Task Review(
    int customerId,
    Guid workflowId,
    SmartBasketReviewRequest request,
    CancellationToken ct)
{
    await RequireCustomer(customerId, ct);

    if (request.Version == Guid.Empty ||
        request.Items is null ||
        request.Items.Count < 1 ||
        request.Items.Count > 50 ||
        request.Items.Any(item =>
            item is null ||
            item.ProductId <= 0 ||
            item.Quantity < 1 ||
            item.Quantity > 100000))
    {
        throw new BadHttpRequestException(
            "Invalid review request.", 400);
    }

    var ids = request.Items
        .Select(item => item.ProductId)
        .ToArray();

    if (ids.Distinct().Count() != ids.Length)
    {
        throw new BadHttpRequestException(
            "Duplicate products are not allowed.", 400);
    }

    await using var transaction =
        await _db.Database.BeginTransactionAsync(ct);

    // Serialize edits/submissions for this customer's workflow.
    var matches = await _db.SmartBasketWorkflows
        .FromSqlInterpolated($"""
            SELECT * FROM "SmartBasketWorkflows"
            WHERE "Id" = {workflowId}
              AND "CustomerId" = {customerId}
            FOR UPDATE
            """)
        .ToListAsync(ct);

    var workflow = matches.SingleOrDefault()
        ?? throw new BadHttpRequestException(
            "Smart Basket request not found.", 404);

    if (workflow.Version != request.Version)
    {
        throw new BadHttpRequestException(
            "This basket has changed. Reload it before editing.", 409);
    }

    if (workflow.Status != SmartBasketStatus.AwaitingCustomerReview)
    {
        throw new BadHttpRequestException(
            "This basket is not available for customer editing.", 409);
    }

    var previousItems = await _db.SmartBasketItems
        .AsNoTracking()
        .Where(item =>
            item.WorkflowId == workflow.Id &&
            item.ProposalRevision == workflow.ProposalRevision)
        .ToDictionaryAsync(item => item.ProductId, ct);

    // This endpoint currently supports quantity changes and removals.
    if (ids.Any(id => !previousItems.ContainsKey(id)))
    {
        throw new BadHttpRequestException(
            "New products require a new validated proposal.", 400);
    }

    using var constraints = JsonDocument.Parse(
        workflow.ConstraintsJson);

    var categoryId = SmartBasketCategoryScope.Read(
        constraints.RootElement);

    var excludedIds = new HashSet<int>();

    if (constraints.RootElement.TryGetProperty(
            "excludedProductIds", out var exclusions))
    {
        foreach (var value in exclusions.EnumerateArray())
            excludedIds.Add(value.GetInt32());
    }

    var products = await _db.Products
        .AsNoTracking()
        .Where(product => ids.Contains(product.Id))
        .ToDictionaryAsync(product => product.Id, ct);

    var newItems = new List<SmartBasketItem>();
    var nextRevision = workflow.ProposalRevision + 1;
    decimal total = 0;

    foreach (var line in request.Items)
    {
        if (!products.TryGetValue(line.ProductId, out var product) ||
            !product.IsFood ||
            (categoryId.HasValue &&
             product.CategoryId != categoryId.Value) ||
            product.Status != "APPROVED" ||
            excludedIds.Contains(product.Id) ||
            product.Price <= 0 ||
            product.StockQuantity < line.Quantity)
        {
            throw new BadHttpRequestException(
                "A selected product is unavailable or has insufficient stock.",
                409);
        }

        var previous = previousItems[product.Id];

        // Do not silently accept a changed price or selling unit.
        if (product.Price != previous.UnitPrice ||
            product.Unit != previous.Unit ||
            product.Name != previous.ProductName)
        {
            throw new BadHttpRequestException(
                "Product details changed. Generate a new proposal.", 409);
        }

        total += product.Price * line.Quantity;

        newItems.Add(new SmartBasketItem
        {
            WorkflowId = workflow.Id,
            ProposalRevision = nextRevision,
            ProductId = product.Id,
            ProductName = product.Name,
            Unit = product.Unit,
            Quantity = line.Quantity,
            UnitPrice = product.Price
        });
    }

    if (total > workflow.Budget)
    {
        throw new BadHttpRequestException(
            "The basket exceeds your budget.", 400);
    }

    var now = DateTime.UtcNow;
    var previousRevision = workflow.ProposalRevision;

    workflow.ProposalRevision = nextRevision;
    workflow.ProposedTotal = total;
    workflow.Version = Guid.NewGuid();
    workflow.UpdatedAt = now;
    workflow.Status = request.SubmitForApproval
        ? SmartBasketStatus.AwaitingApproval
        : SmartBasketStatus.AwaitingCustomerReview;

    workflow.ValidationJson = JsonSerializer.Serialize(new
    {
        source = "BackendCustomerReview",
        valid = true,
        total,
        currency = workflow.Currency,
        revision = nextRevision,
        checkedAt = now
    });

    // Keep previous revisions; insert a new snapshot.
    _db.SmartBasketItems.AddRange(newItems);

    var lastSequence = await _db.SmartBasketSteps
        .Where(step =>
            step.WorkflowId == workflow.Id &&
            step.Attempt == workflow.AttemptCount)
        .MaxAsync(step => (int?)step.Sequence, ct) ?? -1;

    _db.SmartBasketSteps.Add(new SmartBasketStep
    {
        WorkflowId = workflow.Id,
        Attempt = workflow.AttemptCount,
        Sequence = lastSequence + 1,
        AgentName = "Customer",
        ToolName = request.SubmitForApproval
            ? "submit_for_approval"
            : "save_review",
        Status = "Completed",
        StartedAt = now,
        FinishedAt = now,
        InputJson = JsonSerializer.Serialize(new
        {
            customerId,
            previousRevision
        }),
        OutputJson = JsonSerializer.Serialize(new
        {
            revision = nextRevision,
            total,
            status = workflow.Status,
            items = request.Items
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
            "This basket changed. Reload it and try again.", 409);
    }
}
}
