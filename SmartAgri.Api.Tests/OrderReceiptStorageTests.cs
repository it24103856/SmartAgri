using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class OrderReceiptStorageTests
{
    internal sealed class Factory(Func<HttpRequestMessage, HttpResponseMessage> respond) : IHttpClientFactory
    {
        private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
        {
            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
                => Task.FromResult(respond(request));
        }
        public HttpClient CreateClient(string name)
        {
            Assert.Equal("SupabaseStorage", name);
            return new HttpClient(new Handler(respond));
        }
    }

    internal static OrderReceiptStore Store(IHttpClientFactory factory) => new(
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Supabase:Url"] = "https://storage.example.test",
            ["Supabase:ServiceRoleKey"] = "test-only-key",
            ["Supabase:OrderReceiptBucket"] = "order-receipts"
        }).Build(), factory, NullLogger<OrderReceiptStore>.Instance);

    [Theory]
    [InlineData("image/jpeg", ".jpg")]
    [InlineData("image/png", ".png")]
    [InlineData("image/webp", ".webp")]
    public async Task Upload_uses_generated_key_and_private_authenticated_download(string type, string extension)
    {
        byte[] bytes = [1, 2, 3];
        string? uploadedPath = null;
        var store = Store(new Factory(request =>
        {
            Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
            Assert.Equal("test-only-key", request.Headers.GetValues("apikey").Single());
            if (request.Method == HttpMethod.Post)
            {
                uploadedPath = request.RequestUri!.AbsolutePath;
                Assert.Equal(type, request.Content!.Headers.ContentType!.MediaType);
                Assert.Equal("false", request.Headers.GetValues("x-upsert").Single());
                return new(HttpStatusCode.OK);
            }
            Assert.Equal("/storage/v1/object/authenticated/order-receipts/" + Path.GetFileName(uploadedPath), request.RequestUri!.AbsolutePath);
            return new(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) };
        }));
        var key = await store.UploadAsync(bytes, type);
        Assert.EndsWith(extension, key);
        Assert.True(Guid.TryParseExact(key[..32], "N", out _));
        Assert.Equal(bytes, await store.DownloadAsync(key));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Failed_or_lost_upload_returns_safe_error_and_attempts_cleanup(bool lostResponse)
    {
        var deleted = false;
        var store = Store(new Factory(request =>
        {
            if (request.Method == HttpMethod.Delete)
            {
                deleted = true;
                // Even a failed cleanup must preserve the original safe error.
                throw new HttpRequestException("sensitive cleanup details");
            }
            if (lostResponse) throw new HttpRequestException("sensitive upload details");
            return new(HttpStatusCode.InternalServerError) { Content = new StringContent("sensitive body") };
        }));
        var error = await Assert.ThrowsAsync<BadHttpRequestException>(() => store.UploadAsync([1], "image/png"));
        Assert.Equal(502, error.StatusCode);
        Assert.DoesNotContain("sensitive", error.Message);
        Assert.True(deleted);
    }

    [Fact]
    public async Task Invalid_object_key_never_reaches_storage()
    {
        var store = Store(new Factory(_ => throw new InvalidOperationException("Must not send")));
        Assert.Equal(400, (await Assert.ThrowsAsync<BadHttpRequestException>(() => store.DownloadAsync("../other"))).StatusCode);
    }
}
