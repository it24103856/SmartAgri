using System.Text.Json;
using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class PackageImagesTests
{
    [Theory]
    [InlineData("[\"/uploads/packages/someone-elses.jpg\"]", 0)]
    [InlineData("[\"new:1\"]", 1)]
    [InlineData("[\"new:0\",\"new:0\"]", 1)]
    [InlineData("[]", 1)]
    [InlineData("[null]", 0)]
    [InlineData("not-json", 0)]
    public void Rejects_foreign_missing_duplicate_or_invalid_images(string order, int uploads)
    {
        Assert.Equal(400, Assert.Throws<PackageOperationException>(
            () => PackageImageOrder.Validate(order, [], uploads)).StatusCode);
    }

    [Fact]
    public async Task Saves_cover_order_removals_and_protects_other_packages()
    {
        var password = Environment.GetEnvironmentVariable("SMARTAGRI_TEST_DB_PASSWORD");
        Assert.False(string.IsNullOrWhiteSpace(password), "Set SMARTAGRI_TEST_DB_PASSWORD.");
        var connection = new NpgsqlConnectionStringBuilder
        {
            Host = "localhost", Port = 5432, Database = $"smartagri_package_test_{Guid.NewGuid():N}",
            Username = Environment.GetEnvironmentVariable("SMARTAGRI_TEST_DB_USER") ?? "postgres",
            Password = password, Pooling = false
        };
        var directory = Path.Combine(Path.GetTempPath(), $"smartagri-package-images-{Guid.NewGuid():N}");
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["PackageImages:Directory"] = directory,
            ["Supabase:Url"] = "https://storage.example.test",
            ["Supabase:ServiceRoleKey"] = "test-only-key",
            ["Supabase:PackageBucket"] = "packages"
        }).Build();
        var uploaded = new List<string>();
        var deleted = new List<string>();
        var store = new PackageImageStore(
            new TestEnvironment(),
            config,
            NullLogger<PackageImageStore>.Instance,
            new OrderReceiptStorageTests.Factory(request =>
            {
                if (request.Method == HttpMethod.Post)
                    uploaded.Add(request.RequestUri!.AbsolutePath);
                else if (request.Method == HttpMethod.Delete)
                    deleted.Add(request.RequestUri!.AbsolutePath);

                return new(HttpStatusCode.OK);
            }));
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql(connection.ConnectionString).Options);
        try
        {
            await db.Database.EnsureCreatedAsync();
            var admin = new User { FullName = "Owner", Email = "owner@test.example", Role = "ADMIN", PasswordHash = "test" };
            var other = new User { FullName = "Other", Email = "other@test.example", Role = "ADMIN", PasswordHash = "test" };
            var farmer = new User { FullName = "Farmer", Email = "farmer@test.example", Role = "FARMER", PasswordHash = "test" };
            db.Users.AddRange(admin, other, farmer);
            await db.SaveChangesAsync();
            var service = new PackageService(db, store);
            var created = await service.SaveWithImagesAsync(admin.Id, null, Form([Photo(), Photo()], "[\"new:1\",\"new:0\"]"));
            Assert.Equal(2, created.ImageUrls.Count);
            Assert.All(created.ImageUrls, url => Assert.StartsWith(
                "https://storage.example.test/storage/v1/object/public/packages/",
                url));
            Assert.Equal(2, uploaded.Count);

            var edit = Form([Photo()], JsonSerializer.Serialize(new[] { "new:0", created.ImageUrls[1] }));
            edit.Version = created.Version;
            var saved = await service.SaveWithImagesAsync(admin.Id, created.Id, edit);
            Assert.NotEqual(created.ImageUrls[0], saved.ImageUrls[0]);
            Assert.Equal(created.ImageUrls[1], saved.ImageUrls[1]);
            Assert.Single(deleted);
            Assert.Equal(3, uploaded.Count);
            Assert.Equal(saved.ImageUrls, (await service.GetActiveAsync(farmer.Id, null)).Single().ImageUrls);

            var stale = Form([], "[]");
            stale.Version = created.Version;
            Assert.Equal(409, (await Assert.ThrowsAsync<PackageOperationException>(
                () => service.SaveWithImagesAsync(admin.Id, saved.Id, stale))).StatusCode);
            Assert.Equal(403, (await Assert.ThrowsAsync<PackageOperationException>(
                () => service.SaveWithImagesAsync(other.Id, saved.Id, edit))).StatusCode);
            Assert.Equal(400, (await Assert.ThrowsAsync<PackageOperationException>(
                () => service.SaveWithImagesAsync(admin.Id, null, Form([], JsonSerializer.Serialize(saved.ImageUrls))))).StatusCode);

            // A later invalid file must clean up earlier writes in the same upload.
            Assert.Equal(400, (await Assert.ThrowsAsync<PackageOperationException>(() =>
                service.SaveWithImagesAsync(admin.Id, null, Form([Photo(), Photo(invalid: true)], "[\"new:0\",\"new:1\"]")))).StatusCode);
            Assert.Equal(3, deleted.Count);

            var clear = Form([], "[]");
            clear.Version = saved.Version;
            var cleared = await service.SaveWithImagesAsync(admin.Id, saved.Id, clear);
            Assert.Empty(cleared.ImageUrls);
            Assert.Equal(5, deleted.Count);
        }
        finally
        {
            await db.Database.EnsureDeletedAsync();
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    private static SavePackageImagesDto Form(List<IFormFile> images, string order) => new()
    {
        Name = "Land preparation", Description = "Prepare fields", Category = "MACHINERY",
        BaseRate = 100, Images = images, ImageOrderJson = order
    };

    private static IFormFile Photo(bool invalid = false)
    {
        var bytes = invalid ? new byte[16] : Convert.FromBase64String(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZkAAAAASUVORK5CYII=");
        return new FormFile(new MemoryStream(bytes), 0, bytes.Length, "Images", "photo.png")
        {
            Headers = new HeaderDictionary(), ContentType = "image/png"
        };
    }

    private sealed class TestEnvironment : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "Tests";
        public string EnvironmentName { get; set; } = "Development";
        public string ContentRootPath { get; set; } = Path.GetTempPath();
        public string WebRootPath { get; set; } = Path.GetTempPath();
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
    }
}
