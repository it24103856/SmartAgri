using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public class FarmAiCatalogTests
{
    [Fact]
    public void Exclusions_use_shared_catalog_and_reject_unknown_or_duplicate_ids()
    {
        Assert.Equal(10, FarmCropCatalog.Ids.Count);
        var dto = new CreateFarmAnalysisDto
        {
            RequestId = Guid.NewGuid(), FarmId = 1, Objective = "Compare crops",
            PlantingMonth = 4, ExcludedCropIds = FarmCropCatalog.Ids.ToArray()
        };
        List<ValidationResult> errors = new();
        Assert.True(Validator.TryValidateObject(dto, new ValidationContext(dto), errors, true));
        foreach (var ids in new[] { new[] { "unknown" }, new[] { "tomato", "tomato" } })
        {
            dto.ExcludedCropIds = ids;
            errors.Clear();
            Assert.False(Validator.TryValidateObject(dto, new ValidationContext(dto), errors, true));
        }
    }

    [Theory]
    [InlineData("tomato", false, false, true)]
    [InlineData("unknown", false, false, false)]
    [InlineData("tomato", true, false, false)]
    [InlineData("tomato", false, true, false)]
    public async Task Agent_results_validate_new_ids_exclusions_and_duplicates(
        string cropId, bool excluded, bool duplicate, bool valid)
    {
        var workflow = Guid.NewGuid();
        var row = new { crop_id = cropId, eligible = true, suitability = "CONDITIONAL", conflicts = Array.Empty<string>() };
        var json = JsonSerializer.Serialize(new
        {
            workflow_id = workflow, farm_id = 1, action_executed = false,
            status = "COMPLETED", validation = new { passed = true },
            recommendations = duplicate ? new[] { row, row } : new[] { row }
        });
        using var http = new HttpClient(new ResponseHandler(json)) { BaseAddress = new Uri("http://localhost/") };
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["AgentService:InternalKey"] = "test-only"
        }).Build();
        var client = new FarmAiClient(http, config);
        var call = () => client.AnalyzeAsync(new { }, workflow, 1,
            excluded ? new[] { cropId } : Array.Empty<string>(), CancellationToken.None);
        if (valid) Assert.Equal(1, (await call()).GetProperty("recommendations").GetArrayLength());
        else await Assert.ThrowsAsync<InvalidDataException>(call);
    }

    private sealed class ResponseHandler(string json) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
    }
}
