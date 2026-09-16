using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class CheckoutIdempotencyTests
{
    [Fact]
    public async Task Same_request_does_not_create_duplicate_order()
    {
        var password = Environment.GetEnvironmentVariable(
            "SMARTAGRI_TEST_DB_PASSWORD");

        Assert.False(
            string.IsNullOrWhiteSpace(password),
            "Set SMARTAGRI_TEST_DB_PASSWORD before running this test.");

        // Each run uses its own temporary database.
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
                FullName = "Retry Test Customer",
                Email = "retry-customer@example.test",
                PasswordHash = "NotUsedByThisServiceTest",
                Role = "CUSTOMER",
                Status = "ACTIVE"
            };

            var product = new Product
            {
                Name = "Retry Test Product",
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

            // Generate ONCE. Both calls reuse this same request ID.
            var requestId = Guid.NewGuid();

            CustomerCheckoutRequest MakeRequest()
            {
                return new CustomerCheckoutRequest
                {
                    RequestId = requestId,
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
            }

            async Task<int> SendCheckout()
            {
                // Each call gets a new context, like a separate request.
                await using var db = NewDb();

                var service = new CustomerCheckoutService(
                    db,
                    new ConfigurationBuilder().Build(),
                    new EphemeralDataProtectionProvider());

                var order = await service.Create(
                    customer.Id,
                    MakeRequest());

                return order.Id;
            }

            // First checkout: stock should change from 5 to 3.
            var firstOrderId = await SendCheckout();

            Guid versionAfterFirst;

            await using (var afterFirst = NewDb())
            {
                var savedProduct = await afterFirst.Products
                    .AsNoTracking()
                    .SingleAsync(p => p.Id == product.Id);

                Assert.Equal(3, savedProduct.StockQuantity);
                Assert.Equal(
                    1,
                    await afterFirst.CustomerOrders.CountAsync());

                versionAfterFirst = savedProduct.Version;
            }

            // Simulate retry after the first response was lost.
            var retryOrderId = await SendCheckout();

            // The retry must return the original order.
            Assert.Equal(firstOrderId, retryOrderId);

            await using var verify = NewDb();

            var finalProduct = await verify.Products
                .AsNoTracking()
                .SingleAsync(p => p.Id == product.Id);

            // No second stock deduction or product update.
            Assert.Equal(3, finalProduct.StockQuantity);
            Assert.Equal(versionAfterFirst, finalProduct.Version);

            var orders = await verify.CustomerOrders
                .AsNoTracking()
                .Include(o => o.Items)
                .Include(o => o.Payment)
                .ToListAsync();

            var savedOrder = Assert.Single(orders);

            Assert.Equal(firstOrderId, savedOrder.Id);
            Assert.Equal(requestId, savedOrder.RequestId);
            Assert.Equal(customer.Id, savedOrder.UserId);
            Assert.Equal("Confirmed", savedOrder.Status);
            Assert.Equal(500m, savedOrder.TotalAmount);

            var line = Assert.Single(savedOrder.Items);

            Assert.Equal(product.Id, line.ProductId);
            Assert.Equal(2, line.Quantity);
            Assert.Equal(250m, line.UnitPrice);

            Assert.Equal("COD", savedOrder.Payment.Method);
            Assert.Equal("Unpaid", savedOrder.Payment.Status);
            Assert.Equal(500m, savedOrder.Payment.Amount);

            Assert.Equal(
                1,
                await verify.CustomerOrderLines.CountAsync());

            Assert.Equal(
                1,
                await verify.CustomerPayments.CountAsync());
        }
        finally
        {
            // Only this run's temporary database is deleted.
            await setup.Database.EnsureDeletedAsync();
        }
    }
}