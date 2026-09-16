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

public sealed class CustomerOrderAccessTests
{
    [Fact]
    public async Task Customer_cannot_read_another_customers_order()
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

        CustomerCheckoutService NewService(ApplicationDbContext db)
        {
            return new CustomerCheckoutService(
                db,
                new ConfigurationBuilder().Build(),
                new EphemeralDataProtectionProvider());
        }

        await using var setup = NewDb();

        try
        {
            await setup.Database.EnsureCreatedAsync();

            var customerA = new User
            {
                FullName = "Customer A",
                Email = "owner-a@example.test",
                PasswordHash = "NotUsedByThisServiceTest",
                Role = "CUSTOMER",
                Status = "ACTIVE"
            };

            var customerB = new User
            {
                FullName = "Customer B",
                Email = "owner-b@example.test",
                PasswordHash = "NotUsedByThisServiceTest",
                Role = "CUSTOMER",
                Status = "ACTIVE"
            };

            var product = new Product
            {
                Name = "Order Access Test Product",
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

            setup.Users.AddRange(customerA, customerB);
            setup.Products.Add(product);

            await setup.SaveChangesAsync();

            // Give each customer a real order.
            async Task<int> CreateOrder(User customer)
            {
                await using var db = NewDb();

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
                            Quantity = 1,
                            UnitPrice = 250m
                        }
                    }
                };

                var order = await NewService(db).Create(
                    customer.Id,
                    request);

                return order.Id;
            }

            var orderAId = await CreateOrder(customerA);
            var orderBId = await CreateOrder(customerB);

            Assert.NotEqual(orderAId, orderBId);

            // Both owners must be able to read their own orders.
            await using (var ownerDb = NewDb())
            {
                var service = NewService(ownerDb);

                var orderA = await service.Get(customerA.Id, orderAId);
                var orderB = await service.Get(customerB.Id, orderBId);

                Assert.Equal(orderAId, orderA.Id);
                Assert.Equal(customerA.Id, orderA.UserId);

                Assert.Equal(orderBId, orderB.Id);
                Assert.Equal(customerB.Id, orderB.UserId);
            }

            // Customer B must not read A's order, and vice versa.
            await using (var otherCustomerDb = NewDb())
            {
                var service = NewService(otherCustomerDb);

                var errorB =
                    await Assert.ThrowsAsync<BadHttpRequestException>(
                        async () =>
                        {
                            await service.Get(customerB.Id, orderAId);
                        });

                Assert.Equal(404, errorB.StatusCode);

                var errorA =
                    await Assert.ThrowsAsync<BadHttpRequestException>(
                        async () =>
                        {
                            await service.Get(customerA.Id, orderBId);
                        });

                Assert.Equal(404, errorA.StatusCode);
            }

            // Order history must also contain only the owner's orders.
            await using (var historyDb = NewDb())
            {
                var service = NewService(historyDb);

                var historyA = await service.List(customerA.Id);
                var historyB = await service.List(customerB.Id);

                var listedOrderA = Assert.Single(historyA);
                var listedOrderB = Assert.Single(historyB);

                Assert.Equal(orderAId, listedOrderA.Id);
                Assert.Equal(customerA.Id, listedOrderA.UserId);

                Assert.Equal(orderBId, listedOrderB.Id);
                Assert.Equal(customerB.Id, listedOrderB.UserId);
            }

            // Read attempts must not change orders or stock.
            await using var verify = NewDb();

            Assert.Equal(
                2,
                await verify.CustomerOrders.CountAsync());

            var savedProduct = await verify.Products
                .AsNoTracking()
                .SingleAsync(p => p.Id == product.Id);

            Assert.Equal(3, savedProduct.StockQuantity);
        }
        finally
        {
            // Delete only this test run's generated database.
            await setup.Database.EnsureDeletedAsync();
        }
    }
}