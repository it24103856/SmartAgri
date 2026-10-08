using System.Security.Claims;
using System.Net;
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

public class FarmerPurchaseTests
{
    private static ClaimsPrincipal Principal(User user) => new(new ClaimsIdentity([
        new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()), new Claim(ClaimTypes.Role, user.Role)
    ], "test"));

    [Fact]
    public async Task Farmer_orders_receipts_ownership_review_stock_and_history_work()
    {
        await using var database = await SupabaseTestDatabase.CreateAsync();
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql(database.ConnectionString).Options);
        try {
            await database.InitializeAsync(db);
            var farmer = new User { Email = "farmer@test.example", FullName = "Farmer", Role = "FARMER", PasswordHash = "test" };
            var other = new User { Email = "other@test.example", FullName = "Other", Role = "FARMER", PasswordHash = "test" };
            var admin = new User { Email = "admin@test.example", FullName = "Admin", Role = "ADMIN", PasswordHash = "test" };
            var customer = new User { Email = "customer@test.example", FullName = "Customer", Role = "CUSTOMER", PasswordHash = "test" };
            var product = new Product { Name = "Carrots", Category = new Category { Name = "Veg", NormalizedName = "VEG" },
                Price = 100, StockQuantity = 10, Status = "APPROVED" };
            db.AddRange(farmer, other, admin, customer, product);
            await db.SaveChangesAsync();
            var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> {
                ["OrderBankTransfer:BankName"] = "Test bank", ["OrderBankTransfer:AccountName"] = "Test account", ["OrderBankTransfer:AccountNumber"] = "123"
            }).Build();
            var receiptBytes = Convert.FromBase64String(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZkAAAAASUVORK5CYII=");
            var receiptStorage = OrderReceiptStorageTests.Store(
                new OrderReceiptStorageTests.Factory(request =>
                {
                    if (request.Method == HttpMethod.Post)
                        return new(HttpStatusCode.OK);

                    if (request.Method == HttpMethod.Get)
                        return new(HttpStatusCode.OK)
                        {
                            Content = new ByteArrayContent(receiptBytes)
                        };

                    return new(HttpStatusCode.OK);
                }));
            var service = new CustomerCheckoutService(
                db,
                config,
                new EphemeralDataProtectionProvider(),
                receiptStorage);
            Assert.Equal(farmer.Id, await service.CustomerId(Principal(farmer)));
            CustomerCheckoutRequest Request(string method) => new() {
                RequestId = Guid.NewGuid(), FullName = "Buyer", Email = "buyer@test.example", Phone = "0771234567",
                Address = "Test address", City = "Colombo", PaymentMethod = method,
                Items = [new() { ProductId = product.Id, UnitPrice = 100, Quantity = 2 }]
            };
            var request = Request("BANK_TRANSFER");
            var order = await service.Create(farmer.Id, request);
            Assert.Equal(order.Id, (await service.Create(farmer.Id, request)).Id);
            Assert.Equal("AwaitingPayment", order.Status);
            Assert.Equal(10, await db.Products.Where(p => p.Id == product.Id).Select(p => p.StockQuantity).SingleAsync());
            Assert.Contains(await service.List(farmer.Id), o => o.Id == order.Id);
            Assert.Empty(await service.List(other.Id));
            Assert.Equal(404, (await Assert.ThrowsAsync<BadHttpRequestException>(() => service.Get(other.Id, order.Id))).StatusCode);

            SubmitPackageReceiptDto Receipt() {
                var bytes = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZkAAAAASUVORK5CYII=");
                return new() { TransferReference = "BANK-123", Receipt = new FormFile(new MemoryStream(bytes), 0, bytes.Length, "Receipt", "receipt.png") };
            }
            Assert.Equal(404, (await Assert.ThrowsAsync<BadHttpRequestException>(() => service.SubmitOrderReceipt(Principal(other), order.Id, Receipt()))).StatusCode);
            await service.SubmitOrderReceipt(Principal(farmer), order.Id, Receipt());
            var proof = await db.OrderPaymentProofs.SingleAsync();
            Assert.Equal(404, (await Assert.ThrowsAsync<BadHttpRequestException>(() => service.OrderReceipt(Principal(other), proof.Id))).StatusCode);
            Assert.NotEmpty((await service.OrderReceipt(Principal(farmer), proof.Id)).Bytes);
            Assert.Equal(403, (await Assert.ThrowsAsync<BadHttpRequestException>(() => service.ReviewOrderReceipt(Principal(farmer), proof.Id, new() { Version = proof.Version, CreditVerified = true }, true))).StatusCode);
            await service.ReviewOrderReceipt(Principal(admin), proof.Id, new() { Version = proof.Version, AdminNote = "Unreadable receipt" }, false);
            await service.SubmitOrderReceipt(Principal(farmer), order.Id, Receipt());
            proof = await db.OrderPaymentProofs.SingleAsync(p => p.Status == "SUBMITTED");
            var version = proof.Version;
            await service.ReviewOrderReceipt(Principal(admin), proof.Id, new() { Version = version, CreditVerified = true }, true);
            Assert.Equal("Paid", (await service.Get(farmer.Id, order.Id)).Payment.Status);
            Assert.Equal("Confirmed", (await service.Get(farmer.Id, order.Id)).Status);
            Assert.Equal(8, await db.Products.Where(p => p.Id == product.Id).Select(p => p.StockQuantity).SingleAsync());
            Assert.Equal(409, (await Assert.ThrowsAsync<BadHttpRequestException>(() => service.ReviewOrderReceipt(Principal(admin), proof.Id, new() { Version = version, CreditVerified = true }, true))).StatusCode);
            Assert.Single(await db.CustomerOrderStatusHistories.Where(h => h.OrderId == order.Id).ToListAsync());
            Assert.Equal(2, await db.OrderPaymentProofs.CountAsync());
            var cod = await service.Create(customer.Id, Request("COD"));
            Assert.Equal("Confirmed", cod.Status);
            Assert.Equal("Unpaid", cod.Payment.Status);
        }
        finally { }
    }
}
