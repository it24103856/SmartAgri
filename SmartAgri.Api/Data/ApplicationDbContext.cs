using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) 
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    // ඉදිරියට Farmer, Product, Order, Equipment Model එකතු කරන විට මෙහි DbSet එකතු කෙරේ.
}