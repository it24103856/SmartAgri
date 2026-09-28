using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class SmartBasketOptionalBudgetTests
{
    [Theory]
    [InlineData(null, true)]
    [InlineData("1", true)]
    [InlineData("6000", true)]
    [InlineData("1000000", true)]
    [InlineData("0", false)]
    [InlineData("-1", false)]
    [InlineData("1000001", false)]
    [InlineData("1.001", false)]
    public void Optional_budget_preserves_validation_for_supplied_limits(string? value, bool valid)
    {
        var request = new CreateSmartBasketRequest
        {
            RequestId = Guid.NewGuid(), Objective = "Rice",
            Budget = value is null ? null : decimal.Parse(value, System.Globalization.CultureInfo.InvariantCulture)
        };
        Assert.Equal(valid, Validator.TryValidateObject(request, new ValidationContext(request), new List<ValidationResult>(), true));
    }

    [Fact]
    public void Budgetless_request_still_requires_shopping_objective()
    {
        var request = new CreateSmartBasketRequest { RequestId = Guid.NewGuid(), Objective = " " };
        Assert.False(Validator.TryValidateObject(request, new ValidationContext(request), new List<ValidationResult>(), true));
    }

    [Fact]
    public void Availability_survives_persistence_without_losing_category_or_edit_constraints()
    {
        using var response = JsonDocument.Parse("""
            {"unavailable_items":[{"requested_name":"gowa","reason":"not_available"}]}
            """);
        var items = SmartBasketAvailability.ReadAgent(response.RootElement);
        var saved = SmartBasketAvailability.Save("""{"categoryId":2,"excludedProductIds":[3],"addableProducts":[]}""", items);
        using var constraints = JsonDocument.Parse(saved);
        Assert.Equal(2, constraints.RootElement.GetProperty("categoryId").GetInt32());
        Assert.Equal(3, constraints.RootElement.GetProperty("excludedProductIds")[0].GetInt32());
        Assert.Equal(items, SmartBasketAvailability.ReadSaved(saved));
        Assert.Equal("gowa", items[0].RequestedName);
    }

    [Theory]
    [InlineData("{\"unavailable_items\":null}")]
    [InlineData("{\"unavailable_items\":[{\"requested_name\":\"\",\"reason\":\"not_available\"}]}")]
    [InlineData("{\"unavailable_items\":[{\"requested_name\":\"Apple\",\"reason\":\"raw model error\"}]}")]
    [InlineData("{\"unavailable_items\":[{}]}")]
    public void Rejects_malformed_agent_notices(string json)
    {
        using var response = JsonDocument.Parse(json);
        Assert.Throws<InvalidOperationException>(() => SmartBasketAvailability.ReadAgent(response.RootElement));
    }

    [Fact]
    public void Existing_baskets_without_notices_remain_readable()
    {
        Assert.Empty(SmartBasketAvailability.ReadSaved("{}"));
    }

    [Fact]
    public void Catalog_fallback_mode_survives_saved_constraints()
    {
        using var response = JsonDocument.Parse("""{"generation_mode":"catalog_fallback"}""");
        var mode = SmartBasketAvailability.ReadGenerationMode(response.RootElement);
        var saved = SmartBasketAvailability.Save("""{"categoryId":2}""", [], mode);
        Assert.Equal("catalog_fallback", SmartBasketAvailability.ReadSavedGenerationMode(saved));
        Assert.Equal("unknown", SmartBasketAvailability.ReadSavedGenerationMode("{}"));
    }

    [Fact]
    public void Customer_fallback_message_does_not_expose_arbitrary_diagnostics()
    {
        Assert.Contains("simple comma-separated shopping list",
            SmartBasketAvailability.CustomerMessage(SmartBasketAvailability.SimpleListRequired));
        Assert.Null(SmartBasketAvailability.CustomerMessage("Internal server diagnostic"));
        Assert.Null(SmartBasketAvailability.CustomerMessage(null));
    }

    [Fact]
    public void Migration_snapshot_matches_nullable_budget_model()
    {
        using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql("Host=localhost;Database=model_check;Username=test;Password=test")
            .Options);
        Assert.True(db.Model.FindEntityType(typeof(SmartBasketWorkflow))!.FindProperty("Budget")!.IsNullable);
        Assert.False(db.Database.HasPendingModelChanges());
    }
}
