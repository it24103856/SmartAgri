using System.Text.Json;

namespace SmartAgri.Api.Services;

public sealed record UnavailableBasketItem(string RequestedName, string Reason);

// Persist only bounded customer-facing availability data, never agent diagnostics.
public static class SmartBasketAvailability
{
    public const string SimpleListRequired = "Local fallback needs a simple shopping list.";

    public static string ReadGenerationMode(JsonElement response) =>
        response.TryGetProperty("generation_mode", out var mode) &&
        mode.ValueKind == JsonValueKind.String && mode.GetString() == "catalog_fallback"
            ? "catalog_fallback" : "ai";

    public static string ReadSavedGenerationMode(string constraintsJson)
    {
        using var document = JsonDocument.Parse(constraintsJson);
        if (document.RootElement.TryGetProperty("generationMode", out var mode) &&
            mode.ValueKind == JsonValueKind.String &&
            mode.GetString() is "ai" or "catalog_fallback")
            return mode.GetString()!;
        return "unknown";
    }

    public static string? CustomerMessage(string? failureReason) =>
        failureReason == SimpleListRequired
            ? "AI is temporarily unavailable for this request. Please retry later, or enter a simple comma-separated shopping list using catalog names and selling units."
            : null;

    public static UnavailableBasketItem[] ReadAgent(JsonElement response)
    {
        if (!response.TryGetProperty("unavailable_items", out var items))
            return Array.Empty<UnavailableBasketItem>();

        if (items.ValueKind != JsonValueKind.Array || items.GetArrayLength() > 50)
            throw new InvalidOperationException("Invalid availability details.");

        return items.EnumerateArray().Select(item =>
        {
            if (item.ValueKind != JsonValueKind.Object ||
                !item.TryGetProperty("requested_name", out var name) ||
                name.ValueKind != JsonValueKind.String ||
                !item.TryGetProperty("reason", out var reason) ||
                reason.ValueKind != JsonValueKind.String)
                throw new InvalidOperationException("Invalid availability details.");

            var requestedName = name.GetString()!.Trim();
            var reasonCode = reason.GetString()!;
            if (requestedName.Length is < 1 or > 150 ||
                requestedName.Any(char.IsControl) ||
                reasonCode is not ("not_available" or "insufficient_stock"))
                throw new InvalidOperationException("Invalid availability details.");

            return new UnavailableBasketItem(requestedName, reasonCode);
        }).Distinct().ToArray();
    }

    public static string Save(string constraintsJson, UnavailableBasketItem[] items, string generationMode = "ai")
    {
        var constraints = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(constraintsJson)
            ?? throw new InvalidOperationException("Basket constraints are missing.");
        constraints["unavailableItems"] = JsonSerializer.SerializeToElement(items);
        constraints["generationMode"] = JsonSerializer.SerializeToElement(
            generationMode == "catalog_fallback" ? "catalog_fallback" : "ai");
        return JsonSerializer.Serialize(constraints);
    }

    public static UnavailableBasketItem[] ReadSaved(string constraintsJson)
    {
        using var document = JsonDocument.Parse(constraintsJson);
        return document.RootElement.TryGetProperty("unavailableItems", out var items)
            ? items.Deserialize<UnavailableBasketItem[]>() ?? Array.Empty<UnavailableBasketItem>()
            : Array.Empty<UnavailableBasketItem>();
    }
}
