using System.Text.Json;

namespace SmartAgri.Api.Services;

public static class FarmCropCatalog
{
    private static readonly JsonElement Catalog = JsonSerializer.Deserialize<JsonElement>(
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "crop_catalog.json")));

    public static IReadOnlySet<string> Ids { get; } = Catalog.GetProperty("crops")
        .EnumerateObject().Select(crop => crop.Name).ToHashSet(StringComparer.Ordinal);

    public static object Describe() => new
    {
        datasetVersion = Catalog.GetProperty("dataset_version").GetString(),
        crops = Catalog.GetProperty("crops").EnumerateObject().Select(crop => new
        {
            id = crop.Name,
            name = crop.Value.GetProperty("name").GetString(),
            source = crop.Value.GetProperty("source").GetString()
        }).ToArray()
    };
}
