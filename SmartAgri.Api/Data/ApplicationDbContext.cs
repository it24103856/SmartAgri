using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(
        DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<Product> Products { get; set; }
    public DbSet<Cart> Carts { get; set; }
    public DbSet<CartItem> CartItems { get; set; }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
modelBuilder.Entity<Cart>(entity =>
{
    entity.HasIndex(c => c.UserId)
        .IsUnique();

    entity.HasOne<User>()
        .WithMany()
        .HasForeignKey(c => c.UserId)
        .OnDelete(DeleteBehavior.Cascade);
});

modelBuilder.Entity<CartItem>(entity =>
{
    entity.HasIndex(i => new
    {
        i.CartId,
        i.ProductId
    }).IsUnique();

    entity.Property(i => i.UnitPrice)
        .HasPrecision(18, 2);

    entity.HasOne<Cart>()
        .WithMany()
        .HasForeignKey(i => i.CartId)
        .OnDelete(DeleteBehavior.Cascade);

    entity.HasOne<Product>()
        .WithMany()
        .HasForeignKey(i => i.ProductId)
        .OnDelete(DeleteBehavior.Cascade);
});
        modelBuilder.Entity<Category>(entity =>
        {
            entity.Property(c => c.Name)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(c => c.NormalizedName)
                .HasMaxLength(100)
                .IsRequired();

            entity.Property(c => c.Description)
                .HasMaxLength(500);

            entity.HasIndex(c => c.NormalizedName)
                .HasDatabaseName("IX_Categories_NormalizedName")
                .IsUnique();
        });

        modelBuilder.Entity<Product>(entity =>
        {
            entity.Property(p => p.Name)
                .HasMaxLength(150)
                .IsRequired();

            entity.Property(p => p.Price)
                .HasPrecision(18, 2);

            entity.Property(p => p.WeightKg)
                .HasPrecision(12, 3);

            entity.Property(p => p.Unit)
                .HasMaxLength(10)
                .HasDefaultValue("piece")
                .IsRequired();

            entity.Property(p => p.Status)
                .HasMaxLength(16)
                .HasDefaultValue("PENDING")
                .IsRequired();

            entity.Property(p => p.CreatedByRole)
                .HasMaxLength(10)
                .HasDefaultValue("LEGACY");

            entity.Property(p => p.RejectionReason)
                .HasMaxLength(500);

            entity.Property(p => p.ImageUrls)
                .HasColumnType("text[]")
                .HasDefaultValueSql("ARRAY[]::text[]");

            entity.Property(p => p.Version)
                .IsConcurrencyToken();

            entity.HasOne(p => p.Category)
                .WithMany(c => c.Products)
                .HasForeignKey(p => p.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.CreatedBy)
                .WithMany()
                .HasForeignKey(p => p.CreatedById)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.ReviewedBy)
                .WithMany()
                .HasForeignKey(p => p.ReviewedById)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(p => new { p.Status, p.CreatedAt });
        });
    }
}