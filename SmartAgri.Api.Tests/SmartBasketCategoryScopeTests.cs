using System.Text.Json;
using Microsoft.AspNetCore.Http;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class SmartBasketCategoryScopeTests
{
    [Theory]
    [InlineData("{\"categoryId\":null}", null)]
    [InlineData("{\"categoryId\":1}", 1)]
    [InlineData("{\"categoryId\":2147483647}", int.MaxValue)]
    public void Accepts_explicit_all_or_positive_category(string json, int? expected)
    {
        using var document = JsonDocument.Parse(json);

        Assert.Equal(expected, SmartBasketCategoryScope.Read(document.RootElement));
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("{\"categoryId\":0}")]
    [InlineData("{\"categoryId\":-1}")]
    [InlineData("{\"categoryId\":1.5}")]
    [InlineData("{\"categoryId\":2147483648}")]
    [InlineData("{\"categoryId\":\"1\"}")]
    [InlineData("{\"categoryId\":true}")]
    public void Rejects_missing_or_invalid_scope(string json)
    {
        using var document = JsonDocument.Parse(json);

        var error = Assert.Throws<BadHttpRequestException>(
            () => SmartBasketCategoryScope.Read(document.RootElement));

        Assert.Equal(409, error.StatusCode);
    }
}
