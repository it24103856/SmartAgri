using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using SmartAgri.Api.Data;

namespace SmartAgri.StorageMigration;

public enum FieldKind { Scalar, Array, Json, PackageReceipt, OrderReceipt }
public sealed record FieldSpec(string Name, FieldKind Kind, string? Group = null, string StoreType = "text");
public sealed record TableSpec(string Name, string IdColumn, List<FieldSpec> Fields, bool HasVersion);
public sealed record Bucket(string Group, string Name, string Root, bool Private, string PublicPrefix);
public sealed record Source(Bucket Bucket, string Identity, string? File, byte[]? Inline);

public sealed class Catalog
{
    public string ProjectUrl { get; }
    public IReadOnlyList<Bucket> Buckets { get; }
    public Catalog(IConfiguration config, string apiRoot)
    {
        ProjectUrl = Required(config, "Supabase:Url").TrimEnd('/');
        if (!Uri.TryCreate(ProjectUrl, UriKind.Absolute, out var uri) || uri.Scheme != "https" ||
            uri.AbsolutePath != "/" || uri.Query.Length != 0 || uri.Fragment.Length != 0 || uri.UserInfo.Length != 0)
            throw new InvalidOperationException("Supabase:Url must be the HTTPS project URL.");
        var groups = new[] { ("products", "Product"), ("categories", "Category"), ("packages", "Package"),
            ("profiles", "Profile"), ("farms", "Farm") };
        var buckets = groups.Select(g => {
            var name = Required(config, $"Supabase:{g.Item2}Bucket");
            var root = Path.GetFullPath(config[$"{g.Item2}Images:Directory"] ??
                Path.Combine(apiRoot, "..", "SmartAgri.Uploads", g.Item1));
            return new Bucket(g.Item1, name, root, false,
                $"{ProjectUrl}/storage/v1/object/public/{Uri.EscapeDataString(name)}/");
        }).ToList();
        buckets.Add(new("package-receipts", Required(config, "Supabase:PackageReceiptBucket"),
            Path.GetFullPath(Path.Combine(apiRoot, "..", "SmartAgri.Private", "package-receipts")), true, ""));
        buckets.Add(new("order-receipts", Required(config, "Supabase:OrderReceiptBucket"), "", true, ""));
        if (buckets.Select(b => b.Name).Distinct(StringComparer.Ordinal).Count() != buckets.Count)
            throw new InvalidOperationException("Each storage group must have its own configured bucket.");
        Buckets = buckets;
    }

    public static string Required(IConfiguration config, string key) =>
        string.IsNullOrWhiteSpace(config[key]) ? throw new InvalidOperationException($"Missing configuration: {key}") : config[key]!.Trim();

    public static bool SafeName(string name) => name.Length is 36 or 37 &&
        Guid.TryParseExact(name[..32], "N", out _) && name[32..] is ".jpg" or ".png" or ".webp";

    public Bucket Group(string group) => Buckets.Single(b => b.Group == group);

    public (string Outcome, Source? Source) Resolve(string? reference, string? group, string recordId, byte[]? receipt = null)
    {
        if (group == "order-receipts")
        {
            if (reference is not null) return (SafeName(reference) ? "skipped" : "unknown", null);
            return ("source", new(Group(group), "order-receipt:" + recordId, null, receipt ?? []));
        }
        if (string.IsNullOrWhiteSpace(reference)) return ("skipped", null);
        if (group == "package-receipts")
        {
            if (reference.StartsWith("supabase/", StringComparison.Ordinal))
                return (SafeName(reference[9..]) ? "skipped" : "unknown", null);
            if (!SafeName(reference)) return ("unknown", null);
            var bucket = Group(group);
            var path = Path.Combine(bucket.Root, reference);
            return ("source", new(bucket, Path.GetFullPath(path), path, null));
        }
        foreach (var bucket in Buckets.Where(b => !b.Private))
        {
            if (reference.StartsWith(bucket.PublicPrefix, StringComparison.Ordinal))
                return (SafeName(reference[bucket.PublicPrefix.Length..]) && (group == null || bucket.Group == group)
                    ? "skipped" : "unknown", null);
            var prefix = $"/uploads/{bucket.Group}/";
            if (!reference.StartsWith(prefix, StringComparison.Ordinal)) continue;
            var name = reference[prefix.Length..];
            if (!SafeName(name) || (group != null && bucket.Group != group)) return ("unknown", null);
            var path = Path.Combine(bucket.Root, name);
            return ("source", new(bucket, Path.GetFullPath(path), path, null));
        }
        // Unknown origins, signed URLs, queries and traversal are never guessed or fetched.
        return ("unknown", null);
    }

    public static string? Extension(byte[] bytes)
    {
        if (bytes.Length is < 12 or > 5 * 1024 * 1024) return null;
        if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) return ".jpg";
        if (bytes.AsSpan(0, 8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10})) return ".png";
        return Encoding.ASCII.GetString(bytes, 0, 4) == "RIFF" && Encoding.ASCII.GetString(bytes, 8, 4) == "WEBP" ? ".webp" : null;
    }
    public static string ContentType(string extension) => extension switch {
        ".jpg" => "image/jpeg", ".png" => "image/png", ".webp" => "image/webp", _ => throw new InvalidOperationException("Invalid extension.") };
    public static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    public static string ObjectKey(Source source, string extension, string checksum)
    {
        // Reuse legacy GUID names. Order bytes have no filename: derive one deterministically.
        if (source.File is not null) return Path.GetFileName(source.File)[..32] + extension;
        return Hash(Encoding.UTF8.GetBytes(source.Identity + ":" + checksum))[..32] + extension;
    }
    public static string NewReference(Source source, string key) => source.Bucket.Group switch {
        "package-receipts" => "supabase/" + key,
        "order-receipts" => key,
        _ => source.Bucket.PublicPrefix + key
    };

    public static List<TableSpec> Tables(ApplicationDbContext db)
    {
        var result = new List<TableSpec>();
        foreach (var entity in db.Model.GetEntityTypes())
        {
            var table = entity.GetTableName();
            var key = entity.FindPrimaryKey();
            if (table == null || key?.Properties.Count != 1) continue;
            var store = Microsoft.EntityFrameworkCore.Metadata.StoreObjectIdentifier.Table(table, entity.GetSchema());
            var fields = new List<FieldSpec>();
            foreach (var p in entity.GetProperties())
            {
                var name = p.GetColumnName(store)!;
                var type = p.GetColumnType() ?? "text";
                var group = (table, p.Name) switch {
                    ("Products", "ImageUrl" or "ImageUrls") => "products",
                    ("Categories", "ImageUrl") => "categories",
                    ("Users", "ProfileImageUrl") => "profiles",
                    ("Farms", "ImageUrls") => "farms",
                    ("Packages", "ImageUrlsJson") => "packages",
                    ("PackagePaymentProofs", "ReceiptFileName") => "package-receipts",
                    ("OrderPaymentProofs", "ReceiptObjectKey") => "order-receipts",
                    _ => null
                };
                if (group != null || type is "jsonb" or "json" || p.Name.EndsWith("Json", StringComparison.Ordinal))
                    fields.Add(new(name, group switch {
                        "package-receipts" => FieldKind.PackageReceipt,
                        "order-receipts" => FieldKind.OrderReceipt,
                        _ when type == "text[]" => FieldKind.Array,
                        _ when type is "jsonb" or "json" || p.Name.EndsWith("Json", StringComparison.Ordinal) => FieldKind.Json,
                        _ => FieldKind.Scalar
                    }, group, type));
            }
            if (fields.Count > 0) result.Add(new(table, key.Properties[0].GetColumnName(store)!, fields,
                entity.GetProperties().Any(p => p.Name == "Version" && p.IsConcurrencyToken)));
        }
        return result.OrderBy(t => t.Name).ToList();
    }
}
