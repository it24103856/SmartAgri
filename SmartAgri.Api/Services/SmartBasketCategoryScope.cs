using System.Text.Json;

namespace SmartAgri.Api.Services;

public static class SmartBasketCategoryScope
{
    public static int? Read(JsonElement constraints)
    {
        if (constraints.ValueKind != JsonValueKind.Object ||
            !constraints.TryGetProperty("categoryId", out var value))
        {
            throw new BadHttpRequestException(
                "This basket has no category scope. Create a new request.",
                409);
        }

        // Only an explicit JSON null means all food categories.
        if (value.ValueKind == JsonValueKind.Null)
            return null;

        if (value.ValueKind == JsonValueKind.Number &&
            value.TryGetInt32(out var categoryId) &&
            categoryId > 0)
        {
            return categoryId;
        }

        throw new BadHttpRequestException(
            "This basket has an invalid category scope.",
            409);
    }
}
