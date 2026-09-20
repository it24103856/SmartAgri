using System.Net.Http.Json;
using System.Text.Json;

namespace SmartAgri.Api.Services;

public sealed class AgentValidationClient
{
    private readonly HttpClient _http;
    private readonly IConfiguration _configuration;

    public AgentValidationClient(
        HttpClient http,
        IConfiguration configuration)
    {
        _http = http;
        _configuration = configuration;
    }

    public async Task<JsonElement> Validate(
        object payload,
        CancellationToken ct)
    {
        var key = _configuration["AgentService:InternalKey"];

        if (string.IsNullOrWhiteSpace(key))
        {
            throw new BadHttpRequestException(
                "Agent service credentials are not configured.",
                503);
        }

        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            "internal/validate-basket");

        request.Headers.Add("X-Agent-Key", key);
        request.Content = JsonContent.Create(payload);

        try
        {
            using var response = await _http.SendAsync(request, ct);

            if (!response.IsSuccessStatusCode)
            {
                // Do not expose internal response bodies or credentials.
                throw new BadHttpRequestException(
                    "Agent validation service rejected the request.",
                    502);
            }

            var result = await response.Content
                .ReadFromJsonAsync<JsonElement>(
                    cancellationToken: ct);

            if (result.ValueKind != JsonValueKind.Object ||
                !result.TryGetProperty("valid", out var valid) ||
                (valid.ValueKind != JsonValueKind.True &&
                 valid.ValueKind != JsonValueKind.False))
            {
                throw new BadHttpRequestException(
                    "Agent service returned an invalid response.",
                    502);
            }

            return result;
        }
        catch (HttpRequestException)
        {
            throw new BadHttpRequestException(
                "Cannot connect to the Python agent service.",
                503);
        }
        catch (OperationCanceledException)
            when (!ct.IsCancellationRequested)
        {
            throw new BadHttpRequestException(
                "Python agent service timed out.",
                504);
        }
        catch (JsonException)
        {
            throw new BadHttpRequestException(
                "Agent service returned invalid JSON.",
                502);
        }
    }
}