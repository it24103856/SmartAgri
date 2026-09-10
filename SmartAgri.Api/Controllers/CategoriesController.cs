using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/categories")]
[Authorize(Roles = "ADMIN")]
[RequestSizeLimit(30 * 1024 * 1024)]
[RequestFormLimits(MultipartBodyLengthLimit = 30 * 1024 * 1024)]
public sealed class CategoriesController : ControllerBase
{
    private readonly ICategoryService _categories;

    public CategoriesController(ICategoryService categories)
    {
        _categories = categories;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _categories.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var category = await _categories.GetByIdAsync(id);
        return category is null ? NotFound() : Ok(category);
    }

    [HttpPost]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Create([FromForm] SaveCategoryDto dto)
    {
        return Ok(await _categories.CreateAsync(dto));
    }

    [HttpPut("{id:int}")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Update(
        int id,
        [FromForm] SaveCategoryDto dto)
    {
        var category = await _categories.UpdateAsync(id, dto);
        return category is null ? NotFound() : Ok(category);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var result = await _categories.DeleteAsync(id);

        return result switch
        {
            CategoryDeleteResult.Deleted => NoContent(),
            CategoryDeleteResult.NotFound => NotFound(),
            CategoryDeleteResult.InUse => Conflict(new
            {
                message = "This category cannot be deleted while it contains products."
            }),
            _ => StatusCode(500)
        };
    }
}