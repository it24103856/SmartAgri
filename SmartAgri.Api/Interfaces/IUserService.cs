using SmartAgri.Api.DTOs;

namespace SmartAgri.Api.Interfaces;

public interface IUserService
{
    Task<IEnumerable<UserResponseDto>> GetAllUsersAsync();
    Task<UserResponseDto?> GetUserByIdAsync(int id);
    Task<UserResponseDto> CreateUserAsync(CreateUserDto dto);
    Task<UserResponseDto?> UpdateUserAsync(int id, UpdateUserDto dto);
    Task<bool> DeleteUserAsync(int id);
    Task<bool> ChangeStatusAsync(int id, string newStatus);
    Task<UserResponseDto?> ChangeRoleAsync(int id, string newRole); // NEW
    Task<UserStatsDto> GetStatsAsync(); // NEW
}