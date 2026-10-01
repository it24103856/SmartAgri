using System.Net.Http.Json;
using System.Text.Json;

namespace SmartAgri.Api.Services;

public sealed class FarmAiClient
{
    private readonly HttpClient _http;
    private readonly IConfiguration _configuration;

    public FarmAiClient(
        HttpClient http,
        IConfiguration configuration)
    {
        _http = http;
        _configuration = configuration;
    }

    public async Task<JsonElement> AnalyzeAsync(
        object payload,
        Guid workflowId,
        int farmId,
        string[] excludedCropIds,
        CancellationToken ct)
    {
        var key = _configuration["AgentService:InternalKey"];

        if (string.IsNullOrWhiteSpace(key))
        {
            throw new InvalidOperationException(
                "Agent service credentials are missing.");
        }

        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            "internal/analyze-farm");

        request.Headers.Add("X-Agent-Key", key);
        request.Content = JsonContent.Create(payload);

        using var response = await _http.SendAsync(request, ct);

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                "Farmer AI service request failed.",
                null,
                response.StatusCode);
        }

        var result = await response.Content
            .ReadFromJsonAsync<JsonElement>(
                cancellationToken: ct);

        ValidateResult(
            result,
            workflowId,
            farmId,
            excludedCropIds);

        return result;
    }

    private static void ValidateResult(
        JsonElement result,
        Guid workflowId,
        int farmId,
        string[] excludedCropIds)
    {
        if (result.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException(
                "Agent response must be an object.");
        }

        if (result.GetProperty("workflow_id").GetGuid() != workflowId ||
            result.GetProperty("farm_id").GetInt32() != farmId)
        {
            throw new InvalidDataException(
                "Agent response identity mismatch.");
        }

        if (result.GetProperty("action_executed").GetBoolean())
        {
            throw new InvalidDataException(
                "Analysis must not execute actions.");
        }

        var status = result.GetProperty("status").GetString();

        if (status is not (
            "COMPLETED" or
            "NEEDS_INPUT" or
            "NO_MATCH" or
            "FAILED"))
        {
            throw new InvalidDataException(
                "Unknown agent response status.");
        }

        var recommendations =
            result.GetProperty("recommendations");

        if (recommendations.ValueKind != JsonValueKind.Array ||
            recommendations.GetArrayLength() > 3)
        {
            throw new InvalidDataException(
                "Invalid recommendations.");
        }

        if (status != "COMPLETED")
        {
            if (recommendations.GetArrayLength() != 0)
            {
                throw new InvalidDataException(
                    "Unsuccessful analysis contains recommendations.");
            }

            return;
        }

        if (!result.GetProperty("validation")
                .GetProperty("passed").GetBoolean() ||
            recommendations.GetArrayLength() == 0)
        {
            throw new InvalidDataException(
                "Completed analysis failed validation.");
        }

        var allowed = new HashSet<string>(StringComparer.Ordinal)
        {
            "chilli", "okra", "brinjal"
        };

        allowed.ExceptWith(excludedCropIds);

        var seen = new HashSet<string>(StringComparer.Ordinal);

        foreach (var crop in recommendations.EnumerateArray())
        {
            var cropId = crop.GetProperty("crop_id").GetString();

            if (cropId is null ||
                !allowed.Contains(cropId) ||
                !seen.Add(cropId) ||
                !crop.GetProperty("eligible").GetBoolean() ||
                crop.GetProperty("suitability").GetString() !=
                    "CONDITIONAL")
            {
                throw new InvalidDataException(
                    "Invalid crop recommendation.");
            }

            var conflicts = crop.GetProperty("conflicts");

            if (conflicts.ValueKind != JsonValueKind.Array ||
                conflicts.GetArrayLength() != 0)
            {
                throw new InvalidDataException(
                    "Recommended crop contains conflicts.");
            }
        }
    }
}