using System.Text;

namespace SmartAgri.Api.Services;

public class ProductImageStore
{
    private const long MaxFileSize = 5 * 1024 * 1024;
    private const string UrlPrefix = "/uploads/products/";

    private readonly ILogger<ProductImageStore> _logger;

    public string RootDirectory { get; }

    public ProductImageStore(
        IWebHostEnvironment environment,
        IConfiguration configuration,
        ILogger<ProductImageStore> logger)
    {
        _logger = logger;

        RootDirectory = Path.GetFullPath(
            configuration["ProductImages:Directory"]
            ?? Path.Combine(
                environment.ContentRootPath,
                "..",
                "SmartAgri.Uploads",
                "products"));

        Directory.CreateDirectory(RootDirectory);
    }

    public async Task<List<string>> SaveAsync(
        IReadOnlyList<IFormFile> files)
    {
        if (files.Count > 5)
        {
            throw new ProductOperationException(
                400, "You can upload up to 5 images.");
        }

        var savedUrls = new List<string>();

        try
        {
            foreach (var file in files)
            {
                if (file.Length < 12 || file.Length > MaxFileSize)
                {
                    throw new ProductOperationException(
                        400, "Each image must be valid and no larger than 5 MB.");
                }

                await using var input = file.OpenReadStream();

                var header = new byte[12];
                await input.ReadExactlyAsync(header);

                var extension = DetectExtension(header);

                if (extension is null)
                {
                    throw new ProductOperationException(
                        400, "Only JPG, PNG and WebP images are supported.");
                }

                var fileName = $"{Guid.NewGuid():N}{extension}";
                var url = UrlPrefix + fileName;

                // Register before writing so partial files can be cleaned up.
                savedUrls.Add(url);

                var path = Path.Combine(RootDirectory, fileName);

                await using var output = new FileStream(
                    path,
                    FileMode.CreateNew,
                    FileAccess.Write,
                    FileShare.None,
                    81920,
                    useAsync: true);

                await output.WriteAsync(header);
                await input.CopyToAsync(output);
            }

            return savedUrls;
        }
        catch
        {
            DeleteFiles(savedUrls);
            throw;
        }
    }

    public void DeleteFiles(IEnumerable<string> urls)
    {
        foreach (var url in urls.Distinct())
        {
            if (!url.StartsWith(UrlPrefix, StringComparison.Ordinal))
                continue;

            var fileName = Path.GetFileName(url);

            if (url != UrlPrefix + fileName)
                continue;

            if (!Guid.TryParseExact(
                Path.GetFileNameWithoutExtension(fileName),
                "N",
                out _))
                continue;

            var extension = Path.GetExtension(fileName);

            if (extension is not ".jpg" and not ".png" and not ".webp")
                continue;

            try
            {
                File.Delete(Path.Combine(RootDirectory, fileName));
            }
            catch (Exception exception)
                when (exception is IOException or UnauthorizedAccessException)
            {
                _logger.LogWarning(
                    exception,
                    "Could not remove product image {FileName}",
                    fileName);
            }
        }
    }

    private static string? DetectExtension(byte[] header)
    {
        if (header[0] == 0xFF &&
            header[1] == 0xD8 &&
            header[2] == 0xFF)
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

        if (Encoding.ASCII.GetString(header, 0, 4) == "RIFF" &&
            Encoding.ASCII.GetString(header, 8, 4) == "WEBP")
        {
            return ".webp";
        }

        return null;
    }
}