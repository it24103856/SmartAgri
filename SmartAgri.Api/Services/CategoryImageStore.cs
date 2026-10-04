using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;

namespace SmartAgri.Api.Services;

public class CategoryImageStore
{
    private const long MaxFileSize = 5 * 1024 * 1024;
    private const string LocalUrlPrefix = "/uploads/categories/";

    private readonly ILogger<CategoryImageStore> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly string _serviceRoleKey;
    private readonly string _objectEndpoint;
    private readonly string _publicUrlPrefix;

    // Required for serving existing local category images.
    public string RootDirectory { get; }

    public CategoryImageStore(
        IWebHostEnvironment environment,
        IConfiguration configuration,
        ILogger<CategoryImageStore> logger,
        IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;

        RootDirectory = Path.GetFullPath(
            configuration["CategoryImages:Directory"]
            ?? Path.Combine(
                environment.ContentRootPath,
                "..",
                "SmartAgri.Uploads",
                "categories"));

        Directory.CreateDirectory(RootDirectory);

        var projectUrl = Required(configuration, "Supabase:Url")
            .TrimEnd('/');

        if (!Uri.TryCreate(projectUrl, UriKind.Absolute, out var uri)
            || uri.Scheme != Uri.UriSchemeHttps
            || uri.AbsolutePath != "/"
            || !string.IsNullOrEmpty(uri.Query)
            || !string.IsNullOrEmpty(uri.Fragment)
            || !string.IsNullOrEmpty(uri.UserInfo))
        {
            throw new InvalidOperationException(
                "Supabase:Url must be the HTTPS project URL.");
        }

        _serviceRoleKey = Required(
            configuration,
            "Supabase:ServiceRoleKey");

        var bucket = Required(
            configuration,
            "Supabase:CategoryBucket");

        var encodedBucket = Uri.EscapeDataString(bucket);

        _objectEndpoint =
            $"{projectUrl}/storage/v1/object/{encodedBucket}";

        _publicUrlPrefix =
            $"{projectUrl}/storage/v1/object/public/{encodedBucket}/";
    }

    public async Task<List<string>> SaveAsync(
        IReadOnlyList<IFormFile> files)
    {
        if (files.Count > 1)
        {
            throw new BadHttpRequestException(
                "You can upload one category image.");
        }

        var savedUrls = new List<string>();

        using var client =
            _httpClientFactory.CreateClient("SupabaseStorage");

        try
        {
            foreach (var file in files)
            {
                if (file.Length < 12 || file.Length > MaxFileSize)
                {
                    throw new BadHttpRequestException(
                        "Each image must be valid and no larger than 5 MB.");
                }

                await using var input = file.OpenReadStream();

                var header = new byte[12];
                await input.ReadExactlyAsync(header);

                var extension = DetectExtension(header);

                if (extension is null)
                {
                    throw new BadHttpRequestException(
                        "Only JPG, PNG and WebP images are supported.");
                }

                using var image = new MemoryStream();

                await image.WriteAsync(header);

                var buffer = new byte[81920];
                int bytesRead;

                while ((bytesRead = await input.ReadAsync(
                    buffer.AsMemory())) > 0)
                {
                    if (image.Length + bytesRead > MaxFileSize)
                    {
                        throw new BadHttpRequestException(
                            "Each image must be no larger than 5 MB.");
                    }

                    await image.WriteAsync(
                        buffer.AsMemory(0, bytesRead));
                }

                image.Position = 0;

                var fileName = $"{Guid.NewGuid():N}{extension}";
                var publicUrl = _publicUrlPrefix + fileName;

                using var request = CreateRequest(
                    HttpMethod.Post,
                    $"{_objectEndpoint}/{fileName}");

                request.Headers.TryAddWithoutValidation(
                    "x-upsert",
                    "false");

                request.Content = new StreamContent(image);

                request.Content.Headers.ContentType =
                    new MediaTypeHeaderValue(extension switch
                    {
                        ".jpg" => "image/jpeg",
                        ".png" => "image/png",
                        ".webp" => "image/webp",
                        _ => throw new InvalidOperationException()
                    });

                // Register before sending for best-effort cleanup
                // if the upload succeeds but its response is lost.
                savedUrls.Add(publicUrl);

                using var response = await client.SendAsync(request);

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning(
                        "Supabase category upload failed with HTTP {StatusCode}",
                        (int)response.StatusCode);

                    throw new BadHttpRequestException(
                        "Image upload failed. Please try again.",
                        StatusCodes.Status502BadGateway);
                }
            }

            return savedUrls;
        }
        catch (Exception exception)
        {
            await DeleteFilesAsync(savedUrls);

            if (exception is HttpRequestException
                or OperationCanceledException)
            {
                _logger.LogWarning(
                    "Supabase category upload failed: {FailureType}",
                    exception.GetType().Name);

                throw new BadHttpRequestException(
                    "Image storage is unavailable. Please try again.",
                    StatusCodes.Status502BadGateway);
            }

            throw;
        }
    }

    public async Task DeleteFilesAsync(IEnumerable<string> urls)
    {
        using var client =
            _httpClientFactory.CreateClient("SupabaseStorage");

        foreach (var url in urls.Distinct())
        {
            if (string.IsNullOrWhiteSpace(url))
                continue;

            // Existing local category images.
            if (url.StartsWith(
                LocalUrlPrefix,
                StringComparison.Ordinal))
            {
                var fileName = url[LocalUrlPrefix.Length..];

                if (!IsSafeFileName(fileName))
                    continue;

                try
                {
                    File.Delete(
                        Path.Combine(RootDirectory, fileName));
                }
                catch (Exception exception)
                    when (exception is IOException
                        or UnauthorizedAccessException)
                {
                    _logger.LogWarning(
                        exception,
                        "Could not remove local category image {FileName}",
                        fileName);
                }

                continue;
            }

            // Only delete from the configured category bucket.
            if (!url.StartsWith(
                _publicUrlPrefix,
                StringComparison.Ordinal))
            {
                continue;
            }

            var objectName = url[_publicUrlPrefix.Length..];

            if (!IsSafeFileName(objectName))
                continue;

            try
            {
                using var request = CreateRequest(
                    HttpMethod.Delete,
                    _objectEndpoint);

                request.Content = JsonContent.Create(new
                {
                    prefixes = new[] { objectName }
                });

                using var response = await client.SendAsync(request);

                if (!response.IsSuccessStatusCode
                    && response.StatusCode != HttpStatusCode.NotFound)
                {
                    _logger.LogWarning(
                        "Could not remove Supabase category image " +
                        "{FileName}. HTTP {StatusCode}",
                        objectName,
                        (int)response.StatusCode);
                }
            }
            catch (Exception exception)
                when (exception is HttpRequestException
                    or OperationCanceledException)
            {
                // Cleanup failure must not hide the original error.
                _logger.LogWarning(
                    "Could not remove Supabase category image " +
                    "{FileName}: {FailureType}",
                    objectName,
                    exception.GetType().Name);
            }
        }
    }

    private HttpRequestMessage CreateRequest(
        HttpMethod method,
        string url)
    {
        var request = new HttpRequestMessage(method, url);

        request.Headers.Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                _serviceRoleKey);

        request.Headers.Add("apikey", _serviceRoleKey);

        return request;
    }

    private static string Required(
        IConfiguration configuration,
        string key)
    {
        var value = configuration[key];

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Missing configuration: {key}");
        }

        return value.Trim();
    }

    private static bool IsSafeFileName(string fileName)
    {
        if (fileName.Length is not 36 and not 37)
            return false;

        if (!Guid.TryParseExact(
            fileName[..32],
            "N",
            out _))
        {
            return false;
        }

        return fileName[32..] is ".jpg" or ".png" or ".webp";
    }

    private static string? DetectExtension(byte[] header)
    {
        if (header[0] == 0xFF
            && header[1] == 0xD8
            && header[2] == 0xFF)
        {
            return ".jpg";
        }

        var pngSignature = new byte[]
        {
            137, 80, 78, 71, 13, 10, 26, 10
        };

        if (header.AsSpan(0, 8).SequenceEqual(pngSignature))
        {
            return ".png";
        }

        if (Encoding.ASCII.GetString(header, 0, 4) == "RIFF"
            && Encoding.ASCII.GetString(header, 8, 4) == "WEBP")
        {
            return ".webp";
        }

        return null;
    }
}