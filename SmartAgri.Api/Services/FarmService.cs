using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public class FarmService : IFarmService
{
    private readonly ApplicationDbContext _db;
    private readonly FarmImageStore _imageStore;
    private readonly ILogger<FarmService> _logger;

    public FarmService(
        ApplicationDbContext db,
        FarmImageStore imageStore,
        ILogger<FarmService> logger)
    {
        _db = db;
        _imageStore = imageStore;
        _logger = logger;
    }

    private async Task EnsureFarmerExistsAsync(int farmerId)
    {
        var farmer = await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == farmerId);

        if (farmer is null)
        {
            throw new BadHttpRequestException("User not found.", StatusCodes.Status401Unauthorized);
        }

        if (farmer.Role != "FARMER" || farmer.Status != "ACTIVE")
        {
            throw new BadHttpRequestException("An active farmer account is required.", StatusCodes.Status403Forbidden);
        }
    }

    public async Task<List<FarmResponseDto>> GetFarmerFarmsAsync(int farmerId)
    {
        await EnsureFarmerExistsAsync(farmerId);

        var farms = await _db.Farms
            .AsNoTracking()
            .Where(f => f.FarmerId == farmerId)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();

        return farms.Select(MapToDto).ToList();
    }

    public async Task<FarmResponseDto> GetFarmerFarmByIdAsync(int farmerId, int farmId)
    {
        await EnsureFarmerExistsAsync(farmerId);

        var farm = await _db.Farms
            .AsNoTracking()
            .FirstOrDefaultAsync(f => f.Id == farmId && f.FarmerId == farmerId);

        if (farm is null)
        {
            throw new BadHttpRequestException("Farm not found.", StatusCodes.Status404NotFound);
        }

        return MapToDto(farm);
    }

    public async Task<FarmResponseDto> CreateFarmAsync(int farmerId, CreateFarmDto dto)
    {
        await EnsureFarmerExistsAsync(farmerId);

        var uploadedUrls = new List<string>();

        if (dto.Images != null && dto.Images.Count > 0)
        {
            if (dto.Images.Count > 4)
            {
                throw new BadHttpRequestException("A maximum of 4 images can be uploaded.", StatusCodes.Status400BadRequest);
            }

            uploadedUrls = await _imageStore.SaveAsync(dto.Images);
        }

        var farm = new Farm
        {
            FarmerId = farmerId,
            Name = dto.Name.Trim(),
            Location = dto.Location?.Trim(),
            TotalArea = dto.TotalArea,
            AreaUnit = dto.AreaUnit,
            SoilType = dto.SoilType?.Trim(),
            IrrigationType = dto.IrrigationType?.Trim(),
            MainCrops = dto.MainCrops?.Trim(),
            Description = dto.Description?.Trim(),
            ImageUrls = uploadedUrls,
            Status = "ACTIVE",
            CreatedAt = DateTime.UtcNow
        };

        try
        {
            _db.Farms.Add(farm);
            await _db.SaveChangesAsync();
        }
        catch
        {
            if (uploadedUrls.Count > 0)
            {
                _imageStore.DeleteFiles(uploadedUrls);
            }
            throw;
        }

        _logger.LogInformation("Farm '{FarmName}' (ID {FarmId}) created for Farmer ID {FarmerId}", farm.Name, farm.Id, farmerId);

        return MapToDto(farm);
    }

    public async Task<FarmResponseDto> UpdateFarmAsync(int farmerId, int farmId, UpdateFarmDto dto)
    {
        await EnsureFarmerExistsAsync(farmerId);

        var farm = await _db.Farms
            .FirstOrDefaultAsync(f => f.Id == farmId && f.FarmerId == farmerId);

        if (farm is null)
        {
            throw new BadHttpRequestException("Farm not found.", StatusCodes.Status404NotFound);
        }

        // Determine which existing images to keep
        var retainedUrls = (dto.ExistingImageUrls ?? new List<string>())
            .Where(url => farm.ImageUrls.Contains(url))
            .Distinct()
            .ToList();

        // Delete removed images
        var removedUrls = farm.ImageUrls.Except(retainedUrls).ToList();

        var newFilesCount = dto.Images?.Count ?? 0;
        if (retainedUrls.Count + newFilesCount > 4)
        {
            throw new BadHttpRequestException("A farm cannot have more than 4 images in total.", StatusCodes.Status400BadRequest);
        }

        var newUploadedUrls = new List<string>();
        if (dto.Images != null && dto.Images.Count > 0)
        {
            newUploadedUrls = await _imageStore.SaveAsync(dto.Images);
        }

        try
        {
            var finalUrls = new List<string>(retainedUrls);
            finalUrls.AddRange(newUploadedUrls);

            farm.Name = dto.Name.Trim();
            farm.Location = dto.Location?.Trim();
            farm.TotalArea = dto.TotalArea;
            farm.AreaUnit = dto.AreaUnit;
            farm.SoilType = dto.SoilType?.Trim();
            farm.IrrigationType = dto.IrrigationType?.Trim();
            farm.MainCrops = dto.MainCrops?.Trim();
            farm.Description = dto.Description?.Trim();
            farm.ImageUrls = finalUrls;
            farm.UpdatedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync();

            if (removedUrls.Count > 0)
            {
                _imageStore.DeleteFiles(removedUrls);
            }
        }
        catch
        {
            if (newUploadedUrls.Count > 0)
            {
                _imageStore.DeleteFiles(newUploadedUrls);
            }
            throw;
        }

        _logger.LogInformation("Farm ID {FarmId} updated for Farmer ID {FarmerId}", farm.Id, farmerId);

        return MapToDto(farm);
    }

    public async Task DeleteFarmAsync(int farmerId, int farmId)
    {
        await EnsureFarmerExistsAsync(farmerId);

        var farm = await _db.Farms
            .FirstOrDefaultAsync(f => f.Id == farmId && f.FarmerId == farmerId);

        if (farm is null)
        {
            throw new BadHttpRequestException("Farm not found.", StatusCodes.Status404NotFound);
        }

        var urlsToDelete = new List<string>(farm.ImageUrls);

        _db.Farms.Remove(farm);
        await _db.SaveChangesAsync();

        if (urlsToDelete.Count > 0)
        {
            _imageStore.DeleteFiles(urlsToDelete);
        }

        _logger.LogInformation("Farm ID {FarmId} deleted for Farmer ID {FarmerId}", farmId, farmerId);
    }

    private static FarmResponseDto MapToDto(Farm farm)
    {
        return new FarmResponseDto
        {
            Id = farm.Id,
            FarmerId = farm.FarmerId,
            Name = farm.Name,
            Location = farm.Location,
            TotalArea = farm.TotalArea,
            AreaUnit = farm.AreaUnit,
            SoilType = farm.SoilType,
            IrrigationType = farm.IrrigationType,
            MainCrops = farm.MainCrops,
            Description = farm.Description,
            ImageUrls = farm.ImageUrls,
            Status = farm.Status,
            CreatedAt = farm.CreatedAt,
            UpdatedAt = farm.UpdatedAt
        };
    }
}
