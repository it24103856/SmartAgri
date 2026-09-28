using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public class PackageOperationException : Exception
{
    public int StatusCode { get; }

    public PackageOperationException(int statusCode, string message)
        : base(message)
    {
        StatusCode = statusCode;
    }
}

public class PackageService : IPackageService
{
    private readonly ApplicationDbContext _db;

    public PackageService(ApplicationDbContext db)
    {
        _db = db;
    }

    // ---------- shared helpers ----------

    private async Task<User> RequireRoleAsync(int userId, string role)
    {
        var user = await _db.Users.FindAsync(userId);

        if (user is null)
        {
            throw new PackageOperationException(401, "Please sign in again.");
        }

        if (user.Role != role || user.Status != "ACTIVE")
        {
            throw new PackageOperationException(
                403, $"An active {role.ToLowerInvariant()} account is required.");
        }

        return user;
    }

    private async Task<Package> FindPackageAsync(int id)
    {
        return await _db.Packages
            .Include(p => p.CreatedBy)
            .SingleOrDefaultAsync(p => p.Id == id)
            ?? throw new PackageOperationException(404, "Package not found.");
    }

    private static void CheckVersion(Guid current, Guid expected)
    {
        if (current != expected)
        {
            throw new PackageOperationException(
                409, "This changed elsewhere. Refresh and try again.");
        }
    }

    private static PackageResponseDto Map(Package p) => new(
        p.Id,
        p.Name,
        p.Description,
        p.Category,
        p.BaseRate,
        p.MinimumCharge,
        p.CropType,
        p.QuantityPerAcreKg,
        p.MaxLoadKg,
        p.RatePerExtraKg,
        p.IsActive,
        p.CreatedById,
        p.CreatedBy?.FullName ?? "Unknown",
        p.CreatedAt,
        p.UpdatedAt,
        p.Version
    );

    private static BookingResponseDto MapBooking(PackageBooking b) => new(
        b.Id,
        b.PackageId,
        b.Package?.Name ?? "Deleted package",
        b.Package?.Category ?? "",
        b.LandSizeAcres,
        b.DistanceKm,
        b.LoadWeightKg,
        b.CalculatedQuantity,
        b.TotalPrice,
        b.Status,
        b.Notes,
        b.AdminNote,
        b.FarmerId,
        b.Farmer?.FullName ?? "Unknown",
        b.CreatedAt,
        b.Version
    );

    private static void ApplyDetails(Package package, SavePackageDto dto)
    {
        package.Name = dto.Name.Trim();
        package.Description = dto.Description.Trim();
        package.Category = dto.Category;
        package.BaseRate = dto.BaseRate;
        package.MinimumCharge = dto.MinimumCharge;
        package.IsActive = dto.IsActive;

        // Keep only the fields relevant to the chosen category — avoids
        // stale INPUTS data lingering on a package switched to TRANSPORT.
        package.CropType = dto.Category == "INPUTS" ? dto.CropType?.Trim() : null;
        package.QuantityPerAcreKg = dto.Category == "INPUTS" ? dto.QuantityPerAcreKg : null;
        package.MaxLoadKg = dto.Category == "TRANSPORT" ? dto.MaxLoadKg : null;
        package.RatePerExtraKg = dto.Category == "TRANSPORT" ? dto.RatePerExtraKg : null;
    }

    /// Server-authoritative pricing. Used by both the live quote endpoint
    /// and the actual booking, so a client can never send its own total.
    private static (decimal quantity, string unit, decimal total) Calculate(
        Package pkg, CreateBookingDto dto)
    {
        decimal quantity;
        string unit;
        decimal total;

        switch (pkg.Category)
        {
            case "MACHINERY":
                if (dto.LandSizeAcres is not > 0)
                {
                    throw new PackageOperationException(
                        400, "Land size (acres) is required for machinery packages.");
                }

                quantity = dto.LandSizeAcres.Value;
                unit = "acres";
                total = quantity * pkg.BaseRate;
                break;

            case "INPUTS":
                if (dto.LandSizeAcres is not > 0)
                {
                    throw new PackageOperationException(
                        400, "Land size (acres) is required for input packages.");
                }

                quantity = dto.LandSizeAcres.Value * (pkg.QuantityPerAcreKg ?? 0);
                unit = "kg";
                total = quantity * pkg.BaseRate;
                break;

            case "TRANSPORT":
                if (dto.DistanceKm is not > 0)
                {
                    throw new PackageOperationException(
                        400, "Distance (km) is required for transport packages.");
                }

                quantity = dto.DistanceKm.Value;
                unit = "km";
                total = quantity * pkg.BaseRate;

                if (dto.LoadWeightKg is > 0 && pkg.MaxLoadKg is > 0
                    && dto.LoadWeightKg > pkg.MaxLoadKg)
                {
                    var extraKg = dto.LoadWeightKg.Value - pkg.MaxLoadKg.Value;
                    total += extraKg * (pkg.RatePerExtraKg ?? 0);
                }
                break;

            default:
                throw new PackageOperationException(400, "Unsupported package category.");
        }

        if (pkg.MinimumCharge is > 0 && total < pkg.MinimumCharge)
        {
            total = pkg.MinimumCharge.Value;
        }

        return (Math.Round(quantity, 2), unit, Math.Round(total, 2));
    }

    // ---------- admin ----------

    public async Task<List<PackageResponseDto>> GetAllAsync(int adminId)
    {
        await RequireRoleAsync(adminId, "ADMIN");

        var packages = await _db.Packages
            .Include(p => p.CreatedBy)
            .AsNoTracking()
            .Where(p => p.CreatedById == adminId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();

        return packages.Select(Map).ToList();
    }

    public async Task<PackageResponseDto> GetByIdAsync(int adminId, int id)
    {
        await RequireRoleAsync(adminId, "ADMIN");
        return Map(await FindPackageAsync(id));
    }

    public async Task<PackageResponseDto> CreateAsync(int adminId, SavePackageDto dto)
    {
        var admin = await RequireRoleAsync(adminId, "ADMIN");

        var package = new Package
        {
            CreatedById = admin.Id,
            CreatedBy = admin,
            CreatedAt = DateTime.UtcNow,
            Version = Guid.NewGuid(),
        };

        ApplyDetails(package, dto);

        _db.Packages.Add(package);
        await _db.SaveChangesAsync();

        return Map(package);
    }

    public async Task<PackageResponseDto> UpdateAsync(int adminId, int id, SavePackageDto dto)
    {
        await RequireRoleAsync(adminId, "ADMIN");

        var package = await FindPackageAsync(id);

        if (package.CreatedById != adminId)
        {
            throw new PackageOperationException(403, "You can only edit your own packages.");
        }

        ApplyDetails(package, dto);
        package.UpdatedAt = DateTime.UtcNow;
        package.Version = Guid.NewGuid();

        await _db.SaveChangesAsync();

        return Map(package);
    }

    public async Task DeleteAsync(int adminId, int id, Guid version)
    {
        await RequireRoleAsync(adminId, "ADMIN");

        var package = await FindPackageAsync(id);

        if (package.CreatedById != adminId)
        {
            throw new PackageOperationException(403, "You can only delete your own packages.");
        }

        CheckVersion(package.Version, version);

        var hasBookings = await _db.PackageBookings.AnyAsync(b => b.PackageId == id);

        if (hasBookings)
        {
            // Preserve booking history — hide instead of deleting.
            package.IsActive = false;
            package.UpdatedAt = DateTime.UtcNow;
            package.Version = Guid.NewGuid();
            await _db.SaveChangesAsync();
            return;
        }

        _db.Packages.Remove(package);
        await _db.SaveChangesAsync();
    }

    public async Task<List<BookingResponseDto>> GetPendingBookingsAsync(int adminId)
    {
        await RequireRoleAsync(adminId, "ADMIN");

        var bookings = await _db.PackageBookings
            .Include(b => b.Package)
            .Include(b => b.Farmer)
            .AsNoTracking()
            .Where(b => b.Status == "PENDING")
            .OrderBy(b => b.CreatedAt)
            .ToListAsync();

        return bookings.Select(MapBooking).ToList();
    }

    public async Task<BookingResponseDto> ReviewBookingAsync(
        int adminId, int bookingId, ReviewBookingDto dto, bool approve)
    {
        await RequireRoleAsync(adminId, "ADMIN");

        var booking = await _db.PackageBookings
            .Include(b => b.Package)
            .Include(b => b.Farmer)
            .SingleOrDefaultAsync(b => b.Id == bookingId)
            ?? throw new PackageOperationException(404, "Booking not found.");

        if (booking.Status != "PENDING")
        {
            throw new PackageOperationException(409, "This booking was already reviewed.");
        }

        CheckVersion(booking.Version, dto.Version);

        booking.Status = approve ? "CONFIRMED" : "REJECTED";
        booking.AdminNote = dto.AdminNote?.Trim();
        booking.UpdatedAt = DateTime.UtcNow;
        booking.Version = Guid.NewGuid();

        await _db.SaveChangesAsync();

        return MapBooking(booking);
    }

    // ---------- farmer ----------

    public async Task<List<PackageResponseDto>> GetActiveAsync(int farmerId, string? category)
    {
        await RequireRoleAsync(farmerId, "FARMER");

        var query = _db.Packages
            .Include(p => p.CreatedBy)
            .AsNoTracking()
            .Where(p => p.IsActive);

        if (!string.IsNullOrWhiteSpace(category))
        {
            query = query.Where(p => p.Category == category.ToUpperInvariant());
        }

        var packages = await query.OrderBy(p => p.Category).ThenBy(p => p.Name).ToListAsync();

        return packages.Select(Map).ToList();
    }

    public async Task<QuoteResponseDto> QuoteAsync(int farmerId, CreateBookingDto dto)
    {
        await RequireRoleAsync(farmerId, "FARMER");

        var package = await FindPackageAsync(dto.PackageId);

        if (!package.IsActive)
        {
            throw new PackageOperationException(409, "This package is no longer available.");
        }

        var (quantity, unit, total) = Calculate(package, dto);

        return new QuoteResponseDto(package.Id, package.Category, quantity, unit, total);
    }

    public async Task<BookingResponseDto> CreateBookingAsync(int farmerId, CreateBookingDto dto)
    {
        var farmer = await RequireRoleAsync(farmerId, "FARMER");

        var package = await FindPackageAsync(dto.PackageId);

        if (!package.IsActive)
        {
            throw new PackageOperationException(409, "This package is no longer available.");
        }

        var (quantity, _, total) = Calculate(package, dto);

        var booking = new PackageBooking
        {
            PackageId = package.Id,
            Package = package,
            FarmerId = farmer.Id,
            Farmer = farmer,
            LandSizeAcres = dto.LandSizeAcres,
            DistanceKm = dto.DistanceKm,
            LoadWeightKg = dto.LoadWeightKg,
            CalculatedQuantity = quantity,
            TotalPrice = total,
            Status = "PENDING",
            Notes = string.IsNullOrWhiteSpace(dto.Notes) ? null : dto.Notes.Trim(),
            CreatedAt = DateTime.UtcNow,
            Version = Guid.NewGuid(),
        };

        _db.PackageBookings.Add(booking);
        await _db.SaveChangesAsync();

        return MapBooking(booking);
    }

    public async Task<List<BookingResponseDto>> GetBookingsForFarmerAsync(int farmerId)
    {
        await RequireRoleAsync(farmerId, "FARMER");

        var bookings = await _db.PackageBookings
            .Include(b => b.Package)
            .Include(b => b.Farmer)
            .AsNoTracking()
            .Where(b => b.FarmerId == farmerId)
            .OrderByDescending(b => b.CreatedAt)
            .ToListAsync();

        return bookings.Select(MapBooking).ToList();
    }
}
