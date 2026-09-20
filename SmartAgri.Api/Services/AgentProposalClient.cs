using System.Net.Http.Json;
using System.Text.Json;

namespace SmartAgri.Api.Services;

public sealed class AgentProposalClient
{
    private readonly HttpClient _http;
    private readonly IConfiguration _configuration;

    public AgentProposalClient(
        HttpClient http,
        IConfiguration configuration)
    {
        _http = http;
        _configuration = configuration;
    }

    public async Task<JsonElement> Generate(
        object payload,
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
            "internal/propose-basket");

        request.Headers.Add("X-Agent-Key", key);
        request.Content = JsonContent.Create(payload);

        using var response = await _http.SendAsync(request, ct);

        // Never include response bodies or credentials in exceptions.
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"Agent service returned HTTP {(int)response.StatusCode}.");
        }

        var result = await response.Content
            .ReadFromJsonAsync<JsonElement>(cancellationToken: ct);

        if (result.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidOperationException(
                "Agent service returned an invalid response.");
        }

        return result;
    }
}