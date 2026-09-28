using SmartAgri.Api.DTOs;

namespace SmartAgri.Api.Interfaces;

public interface IPackageService
{
    // Admin
    Task<List<PackageResponseDto>> GetAllAsync(int adminId);
    Task<PackageResponseDto> GetByIdAsync(int adminId, int id);
    Task<PackageResponseDto> CreateAsync(int adminId, SavePackageDto dto);
    Task<PackageResponseDto> UpdateAsync(int adminId, int id, SavePackageDto dto);
    Task DeleteAsync(int adminId, int id, Guid version);

    Task<List<BookingResponseDto>> GetPendingBookingsAsync(int adminId);
    Task<BookingResponseDto> ReviewBookingAsync(
        int adminId, int bookingId, ReviewBookingDto dto, bool approve);

    // Farmer
    Task<List<PackageResponseDto>> GetActiveAsync(int farmerId, string? category);
    Task<QuoteResponseDto> QuoteAsync(int farmerId, CreateBookingDto dto);
    Task<BookingResponseDto> CreateBookingAsync(int farmerId, CreateBookingDto dto);
    Task<List<BookingResponseDto>> GetBookingsForFarmerAsync(int farmerId);
}
