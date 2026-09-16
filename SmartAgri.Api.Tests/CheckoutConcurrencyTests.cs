using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Npgsql;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;
using SmartAgri.Api.Services;
using Xunit;

namespace SmartAgri.Api.Tests;

public sealed class CheckoutConcurrencyTests
{
    [Fact]
    public async Task Last_stock_item_can_be_bought_by_only_one_customer()
    {
        var password =
            Environment.GetEnvironmentVariable("SMARTAGRI_TEST_DB_PASSWORD");

        Assert.False(
            string.IsNullOrWhiteSpace(password),
            "Set SMARTAGRI_TEST_DB_PASSWORD before running this test.");

        // A new database name is generated for every test run.
        // The application database connection string is never loaded.
        var databaseName =
            $"smartagri_test_{Guid.NewGuid():N}";

        var connectionString = new NpgsqlConnectionStringBuilder
        {
            Host = "localhost",
            Port = 5432,
            Database = databaseName,
            Username =
                Environment.GetEnvironmentVariable("SMARTAGRI_TEST_DB_USER")
                ?? "postgres",
            Password = password!,
            Pooling = false,
            Timeout = 10,
            CommandTimeout = 30
        }.ConnectionString;

        ApplicationDbContext NewDb(
            SaveChangesInterceptor? interceptor = null)
        {
            var options =
                new DbContextOptionsBuilder<ApplicationDbContext>()
                    .UseNpgsql(connectionString);

            if (interceptor is not null)
                options.AddInterceptors(interceptor);

            return new ApplicationDbContext(options.Options);
        }

        await using var setup = NewDb();

        try
        {
            // Create tables using the current EF model.
            // This test does not test migration history.
            await setup.Database.EnsureCreatedAsync();

            var customerA = new User
            {
                FullName = "Test Customer A",
                Email = "customer-a@example.test",
                PasswordHash = "NotUsedByThisServiceTest",
                Role = "CUSTOMER",
                Status = "ACTIVE"
            };

            var customerB = new User
            {
                FullName = "Test Customer B",
                Email = "customer-b@example.test",
                PasswordHash = "NotUsedByThisServiceTest",
                Role = "CUSTOMER",
                Status = "ACTIVE"
            };

            var category = new Category
            {
                Name = "Test Vegetables",
                NormalizedName = "TEST VEGETABLES"
            };

            var product = new Product
            {
                Name = "Last Test Product",
                Description = "Concurrency test product",
                Category = category,
                Price = 250m,
                Unit = "piece",
                StockQuantity = 1,
                Status = "APPROVED",
                Version = Guid.NewGuid()
            };

            setup.Users.AddRange(customerA, customerB);
            setup.Products.Add(product);

            await setup.SaveChangesAsync();

            CustomerCheckoutRequest MakeRequest(User customer)
            {
                return new CustomerCheckoutRequest
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
            }

            // Both customers reach SaveChanges before either is allowed
            // to save. This makes the conflicting checkout overlap real.
            var gate = new TwoCheckoutSaveGate();

            async Task<bool> Checkout(
                int customerId,
                CustomerCheckoutRequest request)
            {
                // Each customer uses a separate DbContext/connection.
                await using var db = NewDb(gate);

                var service = new CustomerCheckoutService(
                    db,
                    new ConfigurationBuilder().Build(),
                    new EphemeralDataProtectionProvider());

                try
                {
                    await service.Create(customerId, request);
                    return true;
                }
                catch (BadHttpRequestException error)
                    when (error.StatusCode == 409)
                {
                    // Rejecting the losing checkout is expected.
                    Assert.Contains(
                        "stock",
                        error.Message.ToLowerInvariant());

                    return false;
                }
            }

            var results = await Task.WhenAll(
                Checkout(customerA.Id, MakeRequest(customerA)),
                Checkout(customerB.Id, MakeRequest(customerB)));

            // Prove that both checkouts reached the save barrier.
            Assert.True(gate.Arrivals >= 2);

            Assert.Equal(1, results.Count(success => success));
            Assert.Equal(1, results.Count(success => !success));

            // Fresh context: verify persisted data, not tracked objects.
            await using var verify = NewDb();

            var savedProduct = await verify.Products
                .AsNoTracking()
                .SingleAsync(value => value.Id == product.Id);

            Assert.Equal(0, savedProduct.StockQuantity);

            var orders = await verify.CustomerOrders
                .AsNoTracking()
                .Include(order => order.Items)
                .Include(order => order.Payment)
                .ToListAsync();

            var savedOrder = Assert.Single(orders);

            Assert.Equal("Confirmed", savedOrder.Status);
            Assert.Equal(250m, savedOrder.TotalAmount);

            var expectedWinnerId = results[0]
                ? customerA.Id
                : customerB.Id;

            Assert.Equal(expectedWinnerId, savedOrder.UserId);

            var savedLine = Assert.Single(savedOrder.Items);

            Assert.Equal(product.Id, savedLine.ProductId);
            Assert.Equal(1, savedLine.Quantity);

            Assert.Equal("COD", savedOrder.Payment.Method);
            Assert.Equal("Unpaid", savedOrder.Payment.Status);
            Assert.Equal(250m, savedOrder.Payment.Amount);

            // No orphaned lines/payments from the rejected checkout.
            Assert.Equal(
                1,
                await verify.CustomerOrderLines.CountAsync());

            Assert.Equal(
                1,
                await verify.CustomerPayments.CountAsync());
        }
        finally
        {
            // Delete only this run's generated temporary database.
            await setup.Database.EnsureDeletedAsync();
        }
    }

    private sealed class TwoCheckoutSaveGate : SaveChangesInterceptor
    {
        private int _arrivals;

        private readonly TaskCompletionSource<bool> _bothReady =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public int Arrivals => Volatile.Read(ref _arrivals);

        public override async ValueTask<InterceptionResult<int>>
            SavingChangesAsync(
                DbContextEventData eventData,
                InterceptionResult<int> result,
                CancellationToken cancellationToken = default)
        {
            var arrival = Interlocked.Increment(ref _arrivals);

            if (arrival == 2)
                _bothReady.TrySetResult(true);

            // Only synchronize the first attempt from each customer.
            // Let the checkout service's retries proceed normally.
            if (arrival <= 2)
            {
                await _bothReady.Task.WaitAsync(
                    TimeSpan.FromSeconds(20),
                    cancellationToken);
            }

            return result;
        }
    }
}