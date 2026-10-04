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
    private sealed class FailSave : Microsoft.EntityFrameworkCore.Diagnostics.SaveChangesInterceptor
    {
        public override ValueTask<Microsoft.EntityFrameworkCore.Diagnostics.InterceptionResult<int>> SavingChangesAsync(
            Microsoft.EntityFrameworkCore.Diagnostics.DbContextEventData eventData,
            Microsoft.EntityFrameworkCore.Diagnostics.InterceptionResult<int> result,
            CancellationToken cancellationToken = default) => throw new DbUpdateException("Simulated save failure");
    }
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

        ApplicationDbContext NewDb(bool failSave = false)
        {
            var builder =
                new DbContextOptionsBuilder<ApplicationDbContext>()
                    .UseNpgsql(connectionString);
            if (failSave) builder.AddInterceptors(new FailSave());
            var options = builder.Options;

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

            // Legacy receipt bytes remain available only to the owner or an active admin.
            var admin = new User { FullName = "Receipt Admin", Email = "receipt-admin@example.test",
                PasswordHash = "test", Role = "ADMIN", Status = "ACTIVE" };
            setup.Users.Add(admin);
            byte[] legacyBytes = [255, 216, 255, 1];
            var legacy = new OrderPaymentProof { OrderId = orderAId, Amount = 250m,
                Receipt = legacyBytes, ContentType = "image/jpeg", TransferReference = "legacy" };
            setup.OrderPaymentProofs.Add(legacy);
            await setup.SaveChangesAsync();
            System.Security.Claims.ClaimsPrincipal Principal(User user, string? role = null) => new(
                new System.Security.Claims.ClaimsIdentity(new[] {
                    new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Role, role ?? user.Role)
                }, "test"));
            await using (var receiptDb = NewDb())
            {
                var service = NewService(receiptDb);
                Assert.Equal(legacyBytes, (await service.OrderReceipt(Principal(customerA), legacy.Id)).Bytes);
                Assert.Equal(legacyBytes, (await service.OrderReceipt(Principal(admin), legacy.Id)).Bytes);
                Assert.Equal(404, (await Assert.ThrowsAsync<BadHttpRequestException>(
                    () => service.OrderReceipt(Principal(customerB), legacy.Id))).StatusCode);
                Assert.Equal(403, (await Assert.ThrowsAsync<BadHttpRequestException>(
                    () => service.OrderReceipt(Principal(customerB, "ADMIN"), legacy.Id))).StatusCode);
            }

            await using (var paymentSetup = NewDb())
            {
                var order = await paymentSetup.CustomerOrders.Include(o => o.Payment).SingleAsync(o => o.Id == orderBId);
                order.Status = "AwaitingPayment";
                order.Payment.Method = "BANK_TRANSFER";
                order.Payment.Status = "Pending";
                await paymentSetup.SaveChangesAsync();
            }
            var bankConfig = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
                ["OrderBankTransfer:BankName"] = "Test bank", ["OrderBankTransfer:AccountName"] = "Test name",
                ["OrderBankTransfer:AccountNumber"] = "123"
            }).Build();
            SubmitPackageReceiptDto Upload()
            {
                byte[] png = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0];
                return new() { TransferReference = "test", Receipt = new FormFile(new MemoryStream(png), 0, png.Length, "Receipt", "receipt.png") };
            }
            foreach (var failDatabase in new[] { false, true })
            {
                var cleanup = false;
                var storage = OrderReceiptStorageTests.Store(new OrderReceiptStorageTests.Factory(request => {
                    if (request.Method == HttpMethod.Delete) { cleanup = true; return new(System.Net.HttpStatusCode.OK); }
                    return new(failDatabase ? System.Net.HttpStatusCode.OK : System.Net.HttpStatusCode.ServiceUnavailable);
                }));
                await using var uploadDb = NewDb(failDatabase);
                var service = new CustomerCheckoutService(uploadDb, bankConfig, new EphemeralDataProtectionProvider(), storage);
                if (failDatabase)
                    await Assert.ThrowsAsync<DbUpdateException>(() => service.SubmitOrderReceipt(Principal(customerB), orderBId, Upload()));
                else
                    Assert.Equal(502, (await Assert.ThrowsAsync<BadHttpRequestException>(() =>
                        service.SubmitOrderReceipt(Principal(customerB), orderBId, Upload()))).StatusCode);
                Assert.True(cleanup);
                await using var verifyReceipt = NewDb();
                Assert.False(await verifyReceipt.OrderPaymentProofs.AnyAsync(p => p.OrderId == orderBId));
            }

            string? cloudKey = null;
            byte[] cloudBytes = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0];
            var cloudStorage = OrderReceiptStorageTests.Store(new OrderReceiptStorageTests.Factory(request => {
                if (request.Method == HttpMethod.Post) {
                    cloudKey = Path.GetFileName(request.RequestUri!.AbsolutePath);
                    return new(System.Net.HttpStatusCode.OK);
                }
                Assert.Equal(HttpMethod.Get, request.Method);
                return new(System.Net.HttpStatusCode.OK) { Content = new ByteArrayContent(cloudBytes) };
            }));
            await using (var cloudDb = NewDb())
            {
                var service = new CustomerCheckoutService(cloudDb, bankConfig, new EphemeralDataProtectionProvider(), cloudStorage);
                await service.SubmitOrderReceipt(Principal(customerB), orderBId, Upload());
                var savedProof = await cloudDb.OrderPaymentProofs.SingleAsync(p => p.OrderId == orderBId);
                Assert.Equal(cloudKey, savedProof.ReceiptObjectKey);
                Assert.Empty(savedProof.Receipt);
                Assert.Equal("image/png", savedProof.ContentType);
                Assert.Equal(250m, savedProof.Amount);
                Assert.Equal(cloudBytes, (await service.OrderReceipt(Principal(customerB), savedProof.Id)).Bytes);
                Assert.Equal(cloudBytes, (await service.OrderReceipt(Principal(admin), savedProof.Id)).Bytes);
                Assert.Equal(404, (await Assert.ThrowsAsync<BadHttpRequestException>(() =>
                    service.OrderReceipt(Principal(customerA), savedProof.Id))).StatusCode);
                Assert.Equal(409, (await Assert.ThrowsAsync<BadHttpRequestException>(() =>
                    service.SubmitOrderReceipt(Principal(customerB), orderBId, Upload()))).StatusCode);
            }

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
