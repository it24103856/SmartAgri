using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartAgri.Api.Controllers;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class ProductAvailabilityTests
{
    [Fact]
    public async Task Toggle_hides_and_restores_catalog_without_changing_review_and_checks_owner_version()
    {
        var connection = Environment.GetEnvironmentVariable("SMARTAGRI_TEST_CONNECTION");
        Assert.False(string.IsNullOrEmpty(connection), "Set SMARTAGRI_TEST_CONNECTION to a local test server.");
        var builder = new NpgsqlConnectionStringBuilder(connection)
        {
            Database = $"smartagri_availability_test_{Guid.NewGuid():N}",
            Pooling = false
        };
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql(builder.ConnectionString).Options);
        try
        {
            await db.Database.EnsureCreatedAsync();
            var owner = new User { FullName = "Farmer", Email = "farmer@test.example", Role = "FARMER", PasswordHash = "test" };
            var other = new User { FullName = "Other", Email = "other@test.example", Role = "FARMER", PasswordHash = "test" };
            var customer = new User { FullName = "Customer", Email = "customer@test.example", PasswordHash = "test" };
            var category = new Category { Name = "Vegetables", NormalizedName = "VEGETABLES" };
            db.AddRange(owner, other, customer, category);
            await db.SaveChangesAsync();
            var product = new Product {
                Name = "Carrots", Category = category, Price = 200, StockQuantity = 10,
                Status = "APPROVED", CreatedBy = owner, CreatedByRole = "FARMER",
                ReviewedAt = DateTime.UtcNow
            };
            db.Products.Add(product);
            await db.SaveChangesAsync();
            // Availability operations never use image storage.
            var service = new ProductService(db, null!);
            var catalog = new CatalogController(db) {
                ControllerContext = new ControllerContext {
                    HttpContext = new DefaultHttpContext {
                        User = new ClaimsPrincipal(new ClaimsIdentity([
                            new Claim(ClaimTypes.NameIdentifier, customer.Id.ToString()),
                            new Claim(ClaimTypes.Role, "CUSTOMER")
                        ], "test"))
                    }
                }
            };
            async Task<int> Count() {
                var response = Assert.IsType<OkObjectResult>(await catalog.Products(null, null));
                return JsonSerializer.SerializeToElement(response.Value).GetProperty("totalCount").GetInt32();
            }
            Assert.Equal(1, await Count());
            var originalVersion = product.Version;
            var reviewedAt = product.ReviewedAt;
            Assert.Equal(404, (await Assert.ThrowsAsync<ProductOperationException>(() =>
                service.SetFarmerProductAvailabilityAsync(other.Id, product.Id,
                    new() { IsActive = false, Version = originalVersion }))).StatusCode);

            var inactive = await service.SetFarmerProductAvailabilityAsync(owner.Id, product.Id,
                new() { IsActive = false, Version = originalVersion });
            Assert.False(inactive.IsActive);
            Assert.Equal("APPROVED", inactive.Status);
            Assert.Equal(reviewedAt, inactive.ReviewedAt);
            Assert.Equal(0, await Count());
            Assert.IsType<NotFoundObjectResult>(await catalog.ProductDetails(product.Id, default));
            Assert.Equal(409, (await Assert.ThrowsAsync<ProductOperationException>(() =>
                service.SetFarmerProductAvailabilityAsync(owner.Id, product.Id,
                    new() { IsActive = true, Version = originalVersion }))).StatusCode);

            var active = await service.SetFarmerProductAvailabilityAsync(owner.Id, product.Id,
                new() { IsActive = true, Version = inactive.Version });
            Assert.True(active.IsActive);
            Assert.Equal("APPROVED", active.Status);
            Assert.Equal(1, await Count());

            product.Status = "PENDING";
            await db.SaveChangesAsync();
            await service.SetFarmerProductAvailabilityAsync(owner.Id, product.Id,
                new() { IsActive = false, Version = product.Version });
            await service.SetFarmerProductAvailabilityAsync(owner.Id, product.Id,
                new() { IsActive = true, Version = product.Version });
            Assert.Equal("PENDING", product.Status);
            Assert.Equal(0, await Count());

            product.Status = "ARCHIVED";
            await db.SaveChangesAsync();
            Assert.Equal(409, (await Assert.ThrowsAsync<ProductOperationException>(() =>
                service.SetFarmerProductAvailabilityAsync(owner.Id, product.Id,
                    new() { IsActive = true, Version = product.Version }))).StatusCode);
        }
        finally { await db.Database.EnsureDeletedAsync(); }
    }
}
