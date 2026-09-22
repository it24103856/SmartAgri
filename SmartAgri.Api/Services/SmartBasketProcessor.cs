using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class SmartBasketProcessor
{
    private readonly ApplicationDbContext _db;
    private readonly AgentProposalClient _agent;
    private readonly ILogger<SmartBasketProcessor> _logger;

    public SmartBasketProcessor(
        ApplicationDbContext db,
        AgentProposalClient agent,
        ILogger<SmartBasketProcessor> logger)
    {
        _db = db;
        _agent = agent;
        _logger = logger;
    }

    public async Task ProcessNext(CancellationToken ct)
    {
        var now = DateTime.UtcNow;

        var workflow = await _db.SmartBasketWorkflows
            .Include(value => value.Steps)
            .Where(value =>
                value.Status == SmartBasketStatus.Pending ||
                (value.Status == SmartBasketStatus.Planning &&
                 (value.LeaseExpiresAt == null ||
                  value.LeaseExpiresAt <= now)))
            .OrderBy(value => value.CreatedAt)
            .ThenBy(value => value.Id)
            .FirstOrDefaultAsync(ct);

        if (workflow is null)
            return;

        // Close history entries left unfinished by an interrupted worker.
        foreach (var step in workflow.Steps
            .Where(value => value.Status == "Started"))
        {
            step.Status = "Interrupted";
            step.FinishedAt = now;
        }

        workflow.Version = Guid.NewGuid();
        workflow.UpdatedAt = now;

        if (workflow.AttemptCount >= 3)
        {
            workflow.Status = SmartBasketStatus.Failed;
            workflow.FailureReason =
                "Proposal generation was interrupted too many times.";
            workflow.CompletedAt = now;
            workflow.LeaseOwner = null;
            workflow.LeaseExpiresAt = null;

            try
            {
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateConcurrencyException)
            {
                // Another worker changed this request.
            }

            return;
        }

        workflow.AttemptCount++;
        workflow.Status = SmartBasketStatus.Planning;
        workflow.LeaseOwner = Guid.NewGuid().ToString("N");
        workflow.LeaseExpiresAt = now.AddMinutes(8);
        workflow.FailureReason = null;
        workflow.CompletedAt = null;

        workflow.Steps.Add(new SmartBasketStep
        {
            Attempt = workflow.AttemptCount,
            Sequence = 0,
            AgentName = "Backend",
            ToolName = "generate_proposal",
            Status = "Started",
            StartedAt = now
        });

        try
        {
            // Version is configured as an EF concurrency token.
            // Only one competing worker can successfully claim this version.
            await _db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            return;
        }

        var workflowId = workflow.Id;
        var claimVersion = workflow.Version;
        var attempt = workflow.AttemptCount;
        JsonElement? result = null;

        try
        {
            var activeCustomer = await _db.Users.AnyAsync(
                user => user.Id == workflow.CustomerId &&
                    user.Role == "CUSTOMER" &&
                    user.Status == "ACTIVE",
                ct);

            if (!activeCustomer)
                throw new InvalidOperationException("Customer is inactive.");

            var excludedIds = ReadExclusions(workflow.ConstraintsJson);
            var categoryId = ReadCategoryId(workflow.ConstraintsJson);

            // Current Python request contract supports at most 50 products.
            // Do not silently omit part of a larger catalog.
            var catalog = await _db.Products
    .AsNoTracking()
    .Include(product => product.Category)
    .Where(product =>
        (categoryId == null || product.CategoryId == categoryId) &&
        product.IsFood &&
        product.Status == "APPROVED" &&
        product.StockQuantity > 0 &&
        product.Price > 0 &&
        !excludedIds.Contains(product.Id))
    .OrderBy(product => product.Id)
    .Take(51)
    .ToListAsync(ct);

            if (catalog.Count == 0)
                throw new InvalidOperationException("No eligible products.");

            if (catalog.Count > 50)
            {
                throw new InvalidOperationException(
                    "Catalog requires filtering before agent generation.");
            }

            var payload = new
            {
                workflow_id = workflow.Id,
                objective = workflow.Objective,
                budget_minor = ToMinor(workflow.Budget),
                currency = workflow.Currency,
                excluded_product_ids = excludedIds,
               products = catalog.Select(product => new
{
    id = product.Id,
    name = product.Name,
    category_id = product.CategoryId,
    category_name = product.Category.Name,
    unit = product.Unit,
    unit_price_minor = ToMinor(product.Price),
    stock_quantity = product.StockQuantity,
    is_food = product.IsFood,
    approved = product.Status == "APPROVED"
}).ToArray()
            };

            result = await _agent.Generate(payload, ct);
            var response = result.Value;

            if (response.GetProperty("workflow_id").GetGuid() != workflowId)
                throw new InvalidOperationException("Workflow ID mismatch.");

            if (response.GetProperty("status").GetString() != "ProposalReady")
            {
                // Known diagnostic messages only; do not store arbitrary model output.
                var knownReasons = new HashSet<string>(StringComparer.Ordinal)
                {
                    "No eligible food products are available.",
                    "Catalog agent returned an unknown ID.",
                    "Catalog selection contains a conflict.",
                    "No products match this request.",
                    "Model output was incomplete. Please retry.",
                    "Local model timed out. Please retry.",
                    "Local model is unavailable. Check Ollama and the model.",
                    "Local model returned an invalid structured response."
                };

                var reason = "Agent rejected proposal.";

                if (response.TryGetProperty("errors", out var errors) &&
                    errors.ValueKind == JsonValueKind.Array)
                {
                    foreach (var entry in errors.EnumerateArray())
                    {
                        if (entry.ValueKind != JsonValueKind.String)
                            continue;

                        var message = entry.GetString();

                        if (message is not null && knownReasons.Contains(message))
                        {
                            reason = message;
                            break;
                        }
                    }
                }

                throw new InvalidOperationException(reason);
            }

            var validation = response.GetProperty("validation");

            if (!validation.GetProperty("valid").GetBoolean() ||
                validation.GetProperty("workflow_id").GetGuid() != workflowId ||
                validation.GetProperty("currency").GetString() != "LKR")
            {
                throw new InvalidOperationException("Invalid validation result.");
            }

            var lines = validation.GetProperty("items")
                .EnumerateArray()
                .ToArray();

            if (lines.Length == 0 || lines.Length > 50)
                throw new InvalidOperationException("Invalid item count.");

            var ids = lines
                .Select(line => line.GetProperty("product_id").GetInt32())
                .ToArray();

            if (ids.Distinct().Count() != ids.Length ||
                ids.Any(id => excludedIds.Contains(id)) ||
                ids.Any(id => !catalog.Any(product => product.Id == id)))
            {
                throw new InvalidOperationException("Invalid product selection.");
            }

            // Discard old tracked state before checking claim ownership.
            _db.ChangeTracker.Clear();

            var current = await FindOwned(workflowId, claimVersion, ct);

            if (current is null)
                return;

            var stillActive = await _db.Users.AnyAsync(
                user => user.Id == current.CustomerId &&
                    user.Role == "CUSTOMER" &&
                    user.Status == "ACTIVE",
                ct);

            if (!stillActive)
                throw new InvalidOperationException("Customer is inactive.");

            var freshProducts = await _db.Products
                .AsNoTracking()
                .Where(product => ids.Contains(product.Id))
                .ToDictionaryAsync(product => product.Id, ct);

            var items = new List<SmartBasketItem>();
            var revision = current.ProposalRevision + 1;
            long totalMinor = 0;

            foreach (var line in lines)
            {
                var productId = line.GetProperty("product_id").GetInt32();
                var quantity = line.GetProperty("quantity").GetInt32();

                if (!freshProducts.TryGetValue(productId, out var product) ||
    (categoryId.HasValue &&
     product.CategoryId != categoryId.Value) ||
    !product.IsFood ||
    product.Status != "APPROVED" ||
    quantity < 1 ||
    quantity > 100000 ||
    quantity > product.StockQuantity)
                {
                    throw new InvalidOperationException(
                        "Product availability changed.");
                }

                var priceMinor = ToMinor(product.Price);
                var lineMinor = checked(priceMinor * quantity);

                if (line.GetProperty("unit_price_minor").GetInt64() != priceMinor ||
                    line.GetProperty("line_total_minor").GetInt64() != lineMinor ||
                    line.GetProperty("product_name").GetString() != product.Name ||
                    line.GetProperty("unit").GetString() != product.Unit)
                {
                    throw new InvalidOperationException(
                        "Product details or price changed.");
                }

                totalMinor = checked(totalMinor + lineMinor);

                items.Add(new SmartBasketItem
                {
                    WorkflowId = current.Id,
                    ProposalRevision = revision,
                    ProductId = product.Id,
                    ProductName = product.Name,
                    Unit = product.Unit,
                    Quantity = quantity,
                    UnitPrice = product.Price
                });
            }

            if (totalMinor <= 0 ||
                totalMinor > ToMinor(current.Budget) ||
                totalMinor != validation.GetProperty("total_minor").GetInt64())
            {
                throw new InvalidOperationException("Proposal total is invalid.");
            }

            var editing = response.GetProperty("editing");

            var allowedEditIds = editing
                .GetProperty("allowed_product_ids")
                .EnumerateArray()
                .Select(value => value.GetInt32())
                .ToArray();

            var agentExcludedIds = editing
                .GetProperty("excluded_product_ids")
                .EnumerateArray()
                .Select(value => value.GetInt32())
                .ToArray();

            var catalogIds = catalog
                .Select(product => product.Id)
                .ToHashSet();

            var savedExcludedIds = excludedIds
                .Concat(agentExcludedIds)
                .Distinct()
                .ToArray();

            if (allowedEditIds.Length == 0 ||
                allowedEditIds.Length > 50 ||
                allowedEditIds.Distinct().Count() != allowedEditIds.Length ||
                allowedEditIds.Any(id =>
                    !catalogIds.Contains(id) ||
                    savedExcludedIds.Contains(id)) ||
                ids.Any(id => !allowedEditIds.Contains(id)) ||
                agentExcludedIds.Any(id =>
                    id <= 0 ||
                    (!catalogIds.Contains(id) && !excludedIds.Contains(id))))
            {
                throw new InvalidOperationException(
                    "Agent returned invalid editing constraints.");
            }

            // Preserve existing category scope and other constraints.
            var savedConstraints =
                JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(
                    current.ConstraintsJson)
                ?? throw new InvalidOperationException(
                    "Basket constraints are missing.");

            savedConstraints["excludedProductIds"] =
                JsonSerializer.SerializeToElement(savedExcludedIds);

            // Snapshot the catalog details that the agent actually saw.
            savedConstraints["addableProducts"] =
                JsonSerializer.SerializeToElement(
                    catalog
                        .Where(product =>
                            allowedEditIds.Contains(product.Id))
                        .Select(product => new
                        {
                            productId = product.Id,
                            productName = product.Name,
                            unit = product.Unit,
                            unitPrice = product.Price,
                            categoryId = product.CategoryId
                        })
                        .ToArray());

            current.ConstraintsJson =
                JsonSerializer.Serialize(savedConstraints);

            current.PlanJson = response.GetProperty("plan").GetRawText();
            current.ValidationJson = validation.GetRawText();
            current.ProposedTotal = totalMinor / 100m;
            current.ProposalRevision = revision;
            current.Status = SmartBasketStatus.AwaitingCustomerReview;
            current.UpdatedAt = DateTime.UtcNow;
            current.Version = Guid.NewGuid();
            current.LeaseOwner = null;
            current.LeaseExpiresAt = null;

            // Workflow continues through customer review and admin approval.
            current.CompletedAt = null;

            _db.SmartBasketItems.AddRange(items);

            await FinishHistory(
                current, attempt, result, "Completed", null, ct);

            // Items, history and workflow changes commit together.
            await _db.SaveChangesAsync(ct);

            _logger.LogInformation(
                "Smart Basket {WorkflowId} is ready for customer review.",
                workflowId);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // Leave the lease for bounded recovery after restart.
            throw;
        }
        catch (DbUpdateConcurrencyException)
        {
            // A newer owner/state wins. Never overwrite it.
        }
        catch (Exception error)
        {
            _logger.LogWarning(
                "Smart Basket {WorkflowId} failed ({ErrorType}): {Reason}",
                workflowId,
                error.GetType().Name,
                error is InvalidOperationException
                    ? error.Message
                    : "Check the exception type and processing stage.");

            _db.ChangeTracker.Clear();

            var current = await FindOwned(workflowId, claimVersion, ct);

            if (current is null)
                return;

            current.Status = SmartBasketStatus.Failed;
            current.FailureReason =
                "Proposal could not be generated or verified. " +
                "Check the catalog and agent service before submitting again.";
            current.UpdatedAt = DateTime.UtcNow;
            current.CompletedAt = current.UpdatedAt;
            current.Version = Guid.NewGuid();
            current.LeaseOwner = null;
            current.LeaseExpiresAt = null;

            var diagnostic = error is InvalidOperationException
                ? $"{error.GetType().Name}: {error.Message}"
                : error.GetType().Name;

            if (diagnostic.Length > 1900)
                diagnostic = diagnostic[..1900];

            await FinishHistory(
                current, attempt, result, "Failed",
                diagnostic, ct);

            try
            {
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateConcurrencyException)
            {
                // Another worker already changed the request.
            }
        }
    }

    private Task<SmartBasketWorkflow?> FindOwned(
        Guid id,
        Guid version,
        CancellationToken ct)
    {
        var now = DateTime.UtcNow;

        return _db.SmartBasketWorkflows.SingleOrDefaultAsync(
            value => value.Id == id &&
                value.Version == version &&
                value.Status == SmartBasketStatus.Planning &&
                value.LeaseExpiresAt > now,
            ct);
    }

    private async Task FinishHistory(
        SmartBasketWorkflow workflow,
        int attempt,
        JsonElement? response,
        string status,
        string? errorType,
        CancellationToken ct)
    {
        var backendStep = await _db.SmartBasketSteps.SingleAsync(
            value => value.WorkflowId == workflow.Id &&
                value.Attempt == attempt &&
                value.Sequence == 0,
            ct);

        backendStep.Status = status;
        backendStep.FinishedAt = DateTime.UtcNow;
        backendStep.ErrorMessage = errorType;

        if (response is not JsonElement body ||
            !body.TryGetProperty("steps", out var steps) ||
            steps.ValueKind != JsonValueKind.Array)
        {
            return;
        }

        var allowedAgents = new HashSet<string>
        {
            "Planner", "CatalogAgent", "BasketAgent",
            "Validator", "ReviewAgent"
        };

        var sequence = 1;

        foreach (var step in steps.EnumerateArray().Take(10))
        {
            if (step.ValueKind != JsonValueKind.Object ||
                !step.TryGetProperty("agent", out var agentValue) ||
                agentValue.ValueKind != JsonValueKind.String)
            {
                continue;
            }

            var agent = agentValue.GetString()!;

            if (!allowedAgents.Contains(agent))
                continue;

            var stepStatus = "Failed";

            if (step.TryGetProperty("status", out var state) &&
                state.ValueKind == JsonValueKind.String &&
                state.GetString() == "Completed")
            {
                stepStatus = "Completed";
            }

            // Store only a sanitized event summary.
            // These timestamps are backend observation times.
            _db.SmartBasketSteps.Add(new SmartBasketStep
            {
                WorkflowId = workflow.Id,
                Attempt = attempt,
                Sequence = sequence++,
                AgentName = agent,
                ToolName = agent == "Validator" ? "validate_basket" : null,
                Status = stepStatus,
                StartedAt = backendStep.StartedAt,
                FinishedAt = DateTime.UtcNow,
                OutputJson = JsonSerializer.Serialize(new
                {
                    reportedStatus = stepStatus
                })
            });
        }
    }
    private static int? ReadCategoryId(string json)
    {
        using var document = JsonDocument.Parse(json);
        return SmartBasketCategoryScope.Read(document.RootElement);
    }

    private static int[] ReadExclusions(string json)
    {
        using var document = JsonDocument.Parse(json);

        if (!document.RootElement.TryGetProperty(
                "excludedProductIds", out var ids))
        {
            return Array.Empty<int>();
        }

        var result = ids.EnumerateArray()
            .Select(value => value.GetInt32())
            .Distinct()
            .ToArray();

        if (result.Length > 200 || result.Any(id => id <= 0))
            throw new InvalidOperationException("Invalid exclusions.");

        return result;
    }

    private static long ToMinor(decimal amount)
    {
        var minor = amount * 100m;

        if (minor <= 0 ||
            minor != decimal.Truncate(minor) ||
            minor > 100_000_000_000m)
        {
            throw new InvalidOperationException("Invalid money amount.");
        }

        return decimal.ToInt64(minor);
    }
}
