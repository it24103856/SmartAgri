using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace SmartAgri.Api.Services;

// Backend-only access to private customer order receipts. Never returns URLs.
public sealed class OrderReceiptStore(
    IConfiguration config,
    IHttpClientFactory clients,
    ILogger<OrderReceiptStore> logger)
{
    private string Setting(string name) =>
        !string.IsNullOrWhiteSpace(config[$"Supabase:{name}"])
            ? config[$"Supabase:{name}"]!.Trim()
            : throw new InvalidOperationException($"Missing configuration: Supabase:{name}");

    private HttpRequestMessage Request(HttpMethod method, string path)
    {
        var root = Setting("Url").TrimEnd('/');
        if (!Uri.TryCreate(root, UriKind.Absolute, out var uri) ||
            uri.Scheme != "https" || uri.AbsolutePath != "/" ||
            uri.Query.Length != 0 || uri.Fragment.Length != 0 || uri.UserInfo.Length != 0)
            throw new InvalidOperationException("Supabase:Url must be the HTTPS project URL.");
        var bucket = Uri.EscapeDataString(Setting("OrderReceiptBucket"));
        var request = new HttpRequestMessage(method, $"{root}/storage/v1/{path.Replace("{bucket}", bucket)}");
        var key = Setting("ServiceRoleKey");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        request.Headers.Add("apikey", key);
        return request;
    }

    private static bool SafeKey(string key) =>
        key.Length is 36 or 37 && Guid.TryParseExact(key[..32], "N", out _) &&
        key[32..] is ".jpg" or ".png" or ".webp";

    public async Task<string> UploadAsync(byte[] bytes, string contentType)
    {
        var extension = contentType switch
        {
            "image/jpeg" => ".jpg", "image/png" => ".png", "image/webp" => ".webp",
            _ => throw new BadHttpRequestException("Invalid receipt content type.")
        };
        var key = Guid.NewGuid().ToString("N") + extension;
        using var client = clients.CreateClient("SupabaseStorage");
        using var request = Request(HttpMethod.Post, "object/{bucket}/" + key);
        request.Headers.Add("x-upsert", "false");
        request.Content = new ByteArrayContent(bytes);
        request.Content.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        request.Content.Headers.TryAddWithoutValidation("Cache-Control", "no-store");
        try
        {
            using var response = await client.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Order receipt upload failed with HTTP {StatusCode}", (int)response.StatusCode);
                throw new BadHttpRequestException("Receipt upload failed. Please try again.", 502);
            }
            return key;
        }
        catch (Exception exception)
        {
            // A lost response may still have created the object.
            await TryDeleteAsync(key);
            if (exception is HttpRequestException or OperationCanceledException)
                throw new BadHttpRequestException("Receipt storage is unavailable. Please try again.", 502);
            throw;
        }
    }

    public async Task<byte[]> DownloadAsync(string key)
    {
        if (!SafeKey(key)) throw new BadHttpRequestException("Invalid receipt object key.", 400);
        using var client = clients.CreateClient("SupabaseStorage");
        using var request = Request(HttpMethod.Get, "object/authenticated/{bucket}/" + key);
        try
        {
            using var response = await client.SendAsync(request);
            if (response.StatusCode == HttpStatusCode.NotFound)
                throw new BadHttpRequestException("Receipt file not found.", 404);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Order receipt download failed with HTTP {StatusCode}", (int)response.StatusCode);
                throw new BadHttpRequestException("Could not load the receipt. Please try again.", 502);
            }
            return await response.Content.ReadAsByteArrayAsync();
        }
        catch (Exception exception) when (exception is HttpRequestException or OperationCanceledException)
        {
            throw new BadHttpRequestException("Receipt storage is unavailable. Please try again.", 502);
        }
    }

    public async Task TryDeleteAsync(string key)
    {
        if (!SafeKey(key)) return;
        try
        {
            using var client = clients.CreateClient("SupabaseStorage");
            using var request = Request(HttpMethod.Delete, "object/{bucket}");
            request.Content = JsonContent.Create(new { prefixes = new[] { key } });
            using var response = await client.SendAsync(request);
            if (!response.IsSuccessStatusCode && response.StatusCode != HttpStatusCode.NotFound)
                logger.LogWarning("Order receipt cleanup failed with HTTP {StatusCode}", (int)response.StatusCode);
        }
        catch (Exception exception)
        {
            // Do not log exception messages, response bodies, headers or credentials.
            logger.LogWarning("Order receipt cleanup failed: {FailureType}", exception.GetType().Name);
        }
    }
}
