using System.Text.Json;

namespace SmartAgri.Api.Services;

public static class PackageImageOrder
{
    public static List<string> Validate(string json, IReadOnlyCollection<string> existing, int uploadCount)
    {
        List<string>? order;
        try { order = JsonSerializer.Deserialize<List<string>>(json); }
        catch (JsonException) { throw new PackageOperationException(400, "Invalid image order."); }

        if (order is null || order.Count > 6 || uploadCount > 6 ||
            order.Any(string.IsNullOrWhiteSpace) || order.Distinct().Count() != order.Count)
            throw new PackageOperationException(400, "Choose up to 6 unique package images.");

        var newReferences = Enumerable.Range(0, uploadCount).Select(i => $"new:{i}").ToHashSet();
        if (order.Any(reference => !existing.Contains(reference) && !newReferences.Contains(reference)) ||
            newReferences.Any(reference => !order.Contains(reference)))
            throw new PackageOperationException(400, "Images must belong to this package or be included in this upload.");

        return order;
    }
}
