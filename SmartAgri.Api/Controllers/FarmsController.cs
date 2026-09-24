using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "FARMER")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[RequestSizeLimit(30 * 1024 * 1024)]
[RequestFormLimits(MultipartBodyLengthLimit = 30 * 1024 * 1024)]
public class FarmsController : ControllerBase
{
    private readonly IFarmService _farmService;

    public FarmsController(IFarmService farmService)
    {
        _farmService = farmService;
    }

    private int FarmerId
    {
        get
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(claim, out var id) || id <= 0)
            {
                throw new BadHttpRequestException("Please sign in again.", StatusCodes.Status401Unauthorized);
            }
            return id;
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var farms = await _farmService.GetFarmerFarmsAsync(FarmerId);
        return Ok(farms);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var farm = await _farmService.GetFarmerFarmByIdAsync(FarmerId, id);
        return Ok(farm);
    }

    [HttpPost]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Create([FromForm] CreateFarmDto dto)
    {
        var created = await _farmService.CreateFarmAsync(FarmerId, dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Update(int id, [FromForm] UpdateFarmDto dto)
    {
        var updated = await _farmService.UpdateFarmAsync(FarmerId, id, dto);
        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _farmService.DeleteFarmAsync(FarmerId, id);
        return NoContent();
    }
}
