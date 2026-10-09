using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/AI")]
[Authorize(Roles = "FARMER")]
[ResponseCache(
    NoStore = true,
    Location = ResponseCacheLocation.None)]
[RequestSizeLimit(16 * 1024)]
public sealed class AIController : ControllerBase
{
    private readonly FarmAnalysisService _service;

    public AIController(FarmAnalysisService service)
    {
        _service = service;
    }

    private int FarmerId
    {
        get
        {
            var value = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (!int.TryParse(value, out var id) || id <= 0)
            {
                throw new BadHttpRequestException(
                    "Please sign in again.",
                    StatusCodes.Status401Unauthorized);
            }

            return id;
        }
    }

    [HttpGet("crop-catalog")]
    public IActionResult CropCatalog() => Ok(FarmCropCatalog.Describe());

    [HttpPost("analyze-farm")]
    public async Task<IActionResult> Analyze(
        [FromBody] CreateFarmAnalysisDto dto)
    {
        var result = await _service.AnalyzeAsync(
            FarmerId,
            dto);

        if (result.Status == "PROCESSING")
        {
            return StatusCode(
                StatusCodes.Status202Accepted,
                result);
        }

        return Ok(result);
    }

    [HttpGet("analyses")]
    public async Task<IActionResult> History(
        [FromQuery] int page = 1)
    {
        if (page < 1 || page > 10000)
        {
            return BadRequest(new
            {
                message = "Page must be between 1 and 10000."
            });
        }

        return Ok(await _service.GetHistoryAsync(
            FarmerId,
            page));
    }

    [HttpGet("analyses/{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        return Ok(await _service.GetAsync(
            FarmerId,
            id));
    }
}
