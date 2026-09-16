using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class CheckoutPriceChangeTests
{
    [Fact]
    public async Task Changed_price_rejects_checkout_without_changing_stock()
    {
        var password = Environment.GetEnvironmentVariable(
            "SMARTAGRI_TEST_DB_PASSWORD");

        Assert.False(
            string.IsNullOrWhiteSpace(password),
            "Set SMARTAGRI_TEST_DB_PASSWORD before running this test.");

        var databaseName = $"smartagri_test_{Guid.NewGuid():N}";

        var connectionString = new NpgsqlConnectionStringBuilder
        {
            Host = "localhost",
            Port = 5432,
            Database = databaseName,
            Username = Environment.GetEnvironmentVariable(
                "SMARTAGRI_TEST_DB_USER") ?? "postgres",
            Password = password!,
            Pooling = false,
            Timeout = 10,
            CommandTimeout = 30
        }.ConnectionString;

        ApplicationDbContext NewDb()
        {
            var options =
                new DbContextOptionsBuilder<ApplicationDbContext>()
                    .UseNpgsql(connectionString)
                    .Options;

            return new ApplicationDbContext(options);
        }

        await using var setup = NewDb();

        try
        {
            await setup.Database.EnsureCreatedAsync();

            var customer = new User
            {
                FullName = "Price Test Customer",
                Email = "price-test@example.test",
                PasswordHash = "NotUsedByThisServiceTest",
                Role = "CUSTOMER",
                Status = "ACTIVE"
            };

            var product = new Product
            {
                Name = "Price Test Product",
                Category = new Category
                {
                    Name = "Test Vegetables",
                    NormalizedName = "TEST VEGETABLES"
                },
                Price = 250m,
                Unit = "piece",
                StockQuantity = 5,
                Status = "APPROVED",
                Version = Guid.NewGuid()
            };

            setup.Users.Add(customer);
            setup.Products.Add(product);

            await setup.SaveChangesAsync();

            // Customer prepares checkout using the original price.
            var request = new CustomerCheckoutRequest
            {
                RequestId = Guid.NewGuid(),
                FromCart = false,
                FullName = customer.FullName,
                Email = customer.Email,
                Phone = "0771234567",
                Address = "Test Address",
                City = "Colombo",
                PaymentMethod = "COD",
                Items = new List<CustomerCheckoutLineRequest>
                {
                    new()
                    {
                        ProductId = product.Id,
                        Quantity = 2,
                        UnitPrice = 250m
                    }
                }
            };

            // Simulate a committed admin price update before checkout.
            Guid versionAfterPriceChange;

            await using (var adminDb = NewDb())
            {
                var currentProduct = await adminDb.Products
                    .SingleAsync(p => p.Id == product.Id);

                currentProduct.Price = 300m;
                currentProduct.Version = Guid.NewGuid();

                await adminDb.SaveChangesAsync();

                versionAfterPriceChange = currentProduct.Version;
            }

            // A fresh context must read the new database price.
            await using (var checkoutDb = NewDb())
            {
                var service = new CustomerCheckoutService(
                    checkoutDb,
                    new ConfigurationBuilder().Build(),
                    new EphemeralDataProtectionProvider());

                var error =
                    await Assert.ThrowsAsync<BadHttpRequestException>(
                        async () =>
                        {
                            await service.Create(customer.Id, request);
                        });

                Assert.Equal(409, error.StatusCode);

                Assert.Contains(
                    "price changed",
                    error.Message.ToLowerInvariant());
            }

            // Check persisted state using another fresh context.
            await using var verify = NewDb();

            var savedProduct = await verify.Products
                .AsNoTracking()
                .SingleAsync(p => p.Id == product.Id);

            Assert.Equal(300m, savedProduct.Price);
            Assert.Equal(5, savedProduct.StockQuantity);

            // Rejected checkout must not modify the product.
            Assert.Equal(
                versionAfterPriceChange,
                savedProduct.Version);

            Assert.Equal(
                0,
                await verify.CustomerOrders.CountAsync());

            Assert.Equal(
                0,
                await verify.CustomerOrderLines.CountAsync());

            Assert.Equal(
                0,
                await verify.CustomerPayments.CountAsync());
        }
        finally
        {
            // Delete only this test run's generated database.
            await setup.Database.EnsureDeletedAsync();
        }
    }
}