using System.Net;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class FarmAnalysisService
{
    private readonly ApplicationDbContext _db;
    private readonly FarmAiClient _client;
    private readonly ILogger<FarmAnalysisService> _logger;

    public FarmAnalysisService(
        ApplicationDbContext db,
        FarmAiClient client,
        ILogger<FarmAnalysisService> logger)
    {
        _db = db;
        _client = client;
        _logger = logger;
    }

    private async Task EnsureFarmerAsync(int farmerId)
    {
        var allowed = await _db.Users.AsNoTracking()
            .AnyAsync(user =>
                user.Id == farmerId &&
                user.Role == "FARMER" &&
                user.Status == "ACTIVE");

        if (!allowed)
        {
            throw new BadHttpRequestException(
                "An active farmer account is required.",
                StatusCodes.Status403Forbidden);
        }
    }

    private async Task RecoverStaleAsync(int farmerId)
    {
        var cutoff = DateTime.UtcNow.AddMinutes(-10);
        var now = DateTime.UtcNow;

        // A process crash must not leave history PROCESSING forever.
        // Recovery happens when this farmer accesses analysis/history.
        await _db.FarmAiAnalyses
            .Where(row =>
                row.FarmerId == farmerId &&
                row.Status == "PROCESSING" &&
                row.CreatedAt < cutoff)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(row => row.Status, "FAILED")
                .SetProperty(
                    row => row.ErrorCode,
                    "ANALYSIS_INTERRUPTED")
                .SetProperty(
                    row => row.CompletedAt,
                    (DateTime?)now));
    }

    private static FarmAnalysisResponseDto Map(
        FarmAiAnalysis row)
    {
        JsonElement? result = row.ResultJson is null
            ? null
            : JsonSerializer.Deserialize<JsonElement>(
                row.ResultJson);

        return new FarmAnalysisResponseDto(
            row.Id,
            row.RequestId,
            row.SourceFarmId,
            row.FarmName,
            row.Objective,
            row.Status,
            row.ErrorCode,
            row.CreatedAt,
            row.CompletedAt,
            JsonSerializer.Deserialize<JsonElement>(
                row.InputJson),
            result);
    }

    private static FarmAnalysisResponseDto Replay(
        FarmAiAnalysis row,
        string requestJson)
    {
        // PostgreSQL jsonb may reorder properties.
        // Compare JSON structure instead of raw strings.
        if (!JsonNode.DeepEquals(
            JsonNode.Parse(row.RequestJson),
            JsonNode.Parse(requestJson)))
        {
            throw new BadHttpRequestException(
                "This RequestId was already used with different inputs.",
                StatusCodes.Status409Conflict);
        }

        return Map(row);
    }

    public async Task<FarmAnalysisResponseDto> AnalyzeAsync(
        int farmerId,
        CreateFarmAnalysisDto dto)
    {
        await EnsureFarmerAsync(farmerId);
        await RecoverStaleAsync(farmerId);

        var requestJson = JsonSerializer.Serialize(dto);

        var existing = await _db.FarmAiAnalyses
            .AsNoTracking()
            .SingleOrDefaultAsync(row =>
                row.FarmerId == farmerId &&
                row.RequestId == dto.RequestId);

        if (existing is not null)
        {
            return Replay(existing, requestJson);
        }

        var farm = await _db.Farms
            .AsNoTracking()
            .SingleOrDefaultAsync(farm =>
                farm.Id == dto.FarmId &&
                farm.FarmerId == farmerId &&
                farm.Status == "ACTIVE");

        if (farm is null)
        {
            throw new BadHttpRequestException(
                "Active farm not found.",
                StatusCodes.Status404NotFound);
        }

        var soil = farm.SoilType?.Trim();
        var irrigation = farm.IrrigationType?.Trim();

        if (string.IsNullOrWhiteSpace(soil) ||
            string.IsNullOrWhiteSpace(irrigation) ||
            soil.Length > 80 ||
            irrigation.Length > 80)
        {
            throw new BadHttpRequestException(
                "Update the farm's soil and irrigation details first. " +
                "Each value must contain 1–80 characters.",
                StatusCodes.Status400BadRequest);
        }

        var row = new FarmAiAnalysis
        {
            Id = Guid.NewGuid(),
            RequestId = dto.RequestId,
            FarmerId = farmerId,
            FarmId = farm.Id,
            SourceFarmId = farm.Id,
            FarmName = farm.Name,
            Objective = dto.Objective.Trim(),
            RequestJson = requestJson,
            Status = "PROCESSING",
            CreatedAt = DateTime.UtcNow
        };

        var payload = new
        {
            workflow_id = row.Id,
            farm_id = farm.Id,
            objective = row.Objective,
            planting_month = dto.PlantingMonth,
            soil_type = soil,
            irrigation_type = irrigation,
            well_drained = dto.WellDrained,
            temperature_c = dto.TemperatureC,
            soil_ph = dto.SoilPh,
            elevation_m = dto.ElevationM,
            upcountry_wet_zone = dto.UpcountryWetZone,
            rainfall_mm_month = dto.RainfallMmMonth,
            humidity_percent = dto.HumidityPercent,
            excluded_crop_ids = dto.ExcludedCropIds
        };

        row.InputJson = JsonSerializer.Serialize(new
        {
            farmSnapshot = new
            {
                farm.Id,
                farm.Name,
                farm.Location,
                farm.TotalArea,
                farm.AreaUnit,
                farm.SoilType,
                farm.IrrigationType,
                farm.MainCrops
            },
            agentRequest = payload
        });

        _db.FarmAiAnalyses.Add(row);

        try
        {
            // Persist the workflow before contacting Python.
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex)
            when (ex.InnerException is PostgresException
            {
                SqlState: "23505",
                ConstraintName: "UX_FarmAiAnalysis_Request"
            })
        {
            // Concurrent duplicate request: use the existing workflow.
            _db.Entry(row).State = EntityState.Detached;

            existing = await _db.FarmAiAnalyses
                .AsNoTracking()
                .SingleAsync(value =>
                    value.FarmerId == farmerId &&
                    value.RequestId == dto.RequestId);

            return Replay(existing, requestJson);
        }

        // Final updates below use ExecuteUpdate, not tracked SaveChanges.
        _db.Entry(row).State = EntityState.Detached;

        var finalStatus = "FAILED";
        string? resultJson = null;
        string? errorCode = null;

        try
        {
            // Keep processing bounded even if the caller disconnects.
            using var timeout = new CancellationTokenSource(
                TimeSpan.FromSeconds(270));

            var result = await _client.AnalyzeAsync(
                payload,
                row.Id,
                farm.Id,
                dto.ExcludedCropIds,
                timeout.Token);

            finalStatus =
                result.GetProperty("status").GetString()!;

            resultJson = result.GetRawText();

            if (result.TryGetProperty("error_code", out var error) &&
                error.ValueKind == JsonValueKind.String)
            {
                var value = error.GetString();

                errorCode = value is { Length: <= 80 }
                    ? value
                    : "AI_ANALYSIS_FAILED";
            }

            if (finalStatus == "FAILED" && errorCode is null)
            {
                errorCode = "AI_ANALYSIS_FAILED";
            }
        }
        catch (OperationCanceledException)
        {
            errorCode = "AI_TIMEOUT";
        }
        catch (HttpRequestException ex)
        {
            errorCode = ex.StatusCode == HttpStatusCode.TooManyRequests
                ? "AI_BUSY"
                : "AI_UNAVAILABLE";
        }
        catch (Exception ex)
        {
            finalStatus = "FAILED";
            resultJson = null;
            errorCode = "AI_RESPONSE_OR_CONFIGURATION_ERROR";

            // Avoid logging provider response bodies or credentials.
            _logger.LogError(
                "Farm analysis {AnalysisId} failed: {ErrorType}",
                row.Id,
                ex.GetType().Name);
        }

        var completedAt = DateTime.UtcNow;

        await _db.FarmAiAnalyses
            .Where(value =>
                value.Id == row.Id &&
                value.FarmerId == farmerId &&
                value.Status == "PROCESSING")
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(value => value.Status, finalStatus)
                .SetProperty(value => value.ResultJson, resultJson)
                .SetProperty(value => value.ErrorCode, errorCode)
                .SetProperty(
                    value => value.CompletedAt,
                    (DateTime?)completedAt));

        var saved = await _db.FarmAiAnalyses
            .AsNoTracking()
            .SingleAsync(value =>
                value.Id == row.Id &&
                value.FarmerId == farmerId);

        return Map(saved);
    }

    public async Task<FarmAnalysisResponseDto> GetAsync(
        int farmerId,
        Guid id)
    {
        await EnsureFarmerAsync(farmerId);
        await RecoverStaleAsync(farmerId);

        var row = await _db.FarmAiAnalyses
            .AsNoTracking()
            .SingleOrDefaultAsync(value =>
                value.Id == id &&
                value.FarmerId == farmerId);

        if (row is null)
        {
            throw new BadHttpRequestException(
                "Analysis not found.",
                StatusCodes.Status404NotFound);
        }

        return Map(row);
    }

    public async Task<List<FarmAnalysisSummaryDto>> GetHistoryAsync(
        int farmerId,
        int page)
    {
        await EnsureFarmerAsync(farmerId);
        await RecoverStaleAsync(farmerId);

        return await _db.FarmAiAnalyses
            .AsNoTracking()
            .Where(row => row.FarmerId == farmerId)
            .OrderByDescending(row => row.CreatedAt)
            .ThenByDescending(row => row.Id)
            .Skip((page - 1) * 20)
            .Take(20)
            .Select(row => new FarmAnalysisSummaryDto(
                row.Id,
                row.SourceFarmId,
                row.FarmName,
                row.Objective,
                row.Status,
                row.ErrorCode,
                row.CreatedAt,
                row.CompletedAt))
            .ToListAsync();
    }
}