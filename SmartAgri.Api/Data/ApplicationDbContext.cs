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

   public DbSet<CustomerOrder> CustomerOrders => Set<CustomerOrder>();

    public DbSet<CustomerOrderStatusHistory> CustomerOrderStatusHistories =>
        Set<CustomerOrderStatusHistory>();

public DbSet<CustomerOrderLine> CustomerOrderLines =>
    Set<CustomerOrderLine>();


        public DbSet<SmartBasketWorkflow> SmartBasketWorkflows =>
        Set<SmartBasketWorkflow>();

    public DbSet<SmartBasketItem> SmartBasketItems =>
        Set<SmartBasketItem>();

    public DbSet<SmartBasketStep> SmartBasketSteps =>
        Set<SmartBasketStep>();

    public DbSet<SmartBasketApproval> SmartBasketApprovals =>
        Set<SmartBasketApproval>();

public DbSet<CustomerPayment> CustomerPayments =>
    Set<CustomerPayment>();
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
                modelBuilder.Entity<SmartBasketWorkflow>(entity =>
        {
            entity.ToTable("SmartBasketWorkflows", table =>
            {
                table.HasCheckConstraint(
                    "CK_SmartBasketWorkflow_Budget",
                    "\"Budget\" > 0");

                table.HasCheckConstraint(
                    "CK_SmartBasketWorkflow_Total",
                    "\"ProposedTotal\" >= 0 AND " +
                    "\"ProposedTotal\" <= \"Budget\"");

                table.HasCheckConstraint(
                    "CK_SmartBasketWorkflow_Status",
                    "\"Status\" IN (" +
                    "'Pending', 'Planning', 'Validating', " +
                    "'AwaitingApproval', 'Approved', " +
                    "'Rejected', 'Failed')");
            });

            entity.HasKey(value => value.Id);

            entity.HasIndex(value => new
            {
                value.CustomerId,
                value.RequestId
            }).IsUnique();

            entity.HasIndex(value => new
            {
                value.Status,
                value.CreatedAt
            });

            entity.Property(value => value.Version)
                .IsConcurrencyToken();

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(value => value.CustomerId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasMany(value => value.Items)
                .WithOne()
                .HasForeignKey(value => value.WorkflowId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(value => value.Steps)
                .WithOne()
                .HasForeignKey(value => value.WorkflowId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(value => value.Approvals)
                .WithOne()
                .HasForeignKey(value => value.WorkflowId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SmartBasketItem>(entity =>
        {
            entity.ToTable("SmartBasketItems", table =>
            {
                table.HasCheckConstraint(
                    "CK_SmartBasketItem_Quantity",
                    "\"Quantity\" > 0");

                table.HasCheckConstraint(
                    "CK_SmartBasketItem_Price",
                    "\"UnitPrice\" > 0");

                table.HasCheckConstraint(
                    "CK_SmartBasketItem_Revision",
                    "\"ProposalRevision\" > 0");
            });

            entity.HasKey(value => value.Id);

            entity.HasIndex(value => new
            {
                value.WorkflowId,
                value.ProposalRevision,
                value.ProductId
            }).IsUnique();

            entity.HasOne<Product>()
                .WithMany()
                .HasForeignKey(value => value.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<SmartBasketStep>(entity =>
        {
            entity.ToTable("SmartBasketSteps");

            entity.HasKey(value => value.Id);

            entity.HasIndex(value => new
            {
                value.WorkflowId,
                value.Attempt,
                value.Sequence
            }).IsUnique();
        });

        modelBuilder.Entity<SmartBasketApproval>(entity =>
        {
            entity.ToTable("SmartBasketApprovals", table =>
            {
                table.HasCheckConstraint(
                    "CK_SmartBasketApproval_Decision",
                    "\"Decision\" IN (" +
                    "'Approved', 'Rejected', 'RevisionRequested')");

                table.HasCheckConstraint(
                    "CK_SmartBasketApproval_Revision",
                    "\"ProposalRevision\" > 0");
            });

            entity.HasKey(value => value.Id);

            // One decision per proposal revision.
            entity.HasIndex(value => new
            {
                value.WorkflowId,
                value.ProposalRevision
            }).IsUnique();

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(value => value.AdminId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CustomerOrderStatusHistory>(entity =>
        {
            entity.Property(h => h.FromStatus)
                .HasMaxLength(40)
                .IsRequired();

            entity.Property(h => h.ToStatus)
                .HasMaxLength(40)
                .IsRequired();

            entity.Property(h => h.Note)
                .HasMaxLength(500);

            entity.HasIndex(h => new { h.OrderId, h.CreatedAt });

            entity.HasOne<CustomerOrder>()
                .WithMany()
                .HasForeignKey(h => h.OrderId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(h => h.ChangedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CustomerOrder>()
            .HasIndex(o => new { o.Status, o.CreatedAt });
        
modelBuilder.Entity<Cart>(entity =>
{
    entity.HasIndex(c => c.UserId)
        .IsUnique();

    entity.HasOne<User>()
        .WithMany()
        .HasForeignKey(c => c.UserId)
        .OnDelete(DeleteBehavior.Cascade);
});
modelBuilder.Entity<CustomerOrder>(entity =>
{
    entity.HasIndex(o => new { o.UserId, o.RequestId })
        .IsUnique();

    entity.HasOne<User>()
        .WithMany()
        .HasForeignKey(o => o.UserId)
        .OnDelete(DeleteBehavior.Restrict);

    entity.HasMany(o => o.Items)
        .WithOne()
        .HasForeignKey(i => i.OrderId)
        .OnDelete(DeleteBehavior.Cascade);

    entity.HasOne(o => o.Payment)
        .WithOne()
        .HasForeignKey<CustomerPayment>(p => p.OrderId)
        .OnDelete(DeleteBehavior.Cascade);
});

modelBuilder.Entity<CustomerPayment>(entity =>
{
    entity.HasIndex(p => p.GatewayOrderId)
        .IsUnique();
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
