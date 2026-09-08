using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Interfaces;
using SmartAgri.Api.Routes;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")] // every action in this controller requires a valid ADMIN token
public class UserController : ControllerBase
{
    private readonly IUserService _userService;

    public UserController(IUserService userService)
    {
        _userService = userService;
    }

    // 1. GET: api/users
    [HttpGet(UserRoutes.GetAll)]
    public async Task<ActionResult<IEnumerable<UserResponseDto>>> GetAllUsers()
    {
        var users = await _userService.GetAllUsersAsync();
        return Ok(users);
    }

    // 2. GET: api/users/stats
    // Uses UserRoutes.Stats (literal, no {id}) so it can never collide
    // with GetById's "{id:int}" route below.
    [HttpGet(UserRoutes.Stats)]
    public async Task<ActionResult<UserStatsDto>> GetStats()
    {
        var stats = await _userService.GetStatsAsync();
        return Ok(stats);
    }

    // 3. GET: api/users/{id}
    [HttpGet(UserRoutes.GetById)]
    public async Task<ActionResult<UserResponseDto>> GetUserById(int id)
    {
        var user = await _userService.GetUserByIdAsync(id);
        if (user == null)
            return NotFound(new { message = "User not found" });

        return Ok(user);
    }

    // 4. POST: api/users
    [HttpPost(UserRoutes.Create)]
    public async Task<ActionResult<UserResponseDto>> CreateUser([FromBody] CreateUserDto dto)
    {
        try
        {
            var createdUser = await _userService.CreateUserAsync(dto);
            return CreatedAtAction(nameof(GetUserById), new { id = createdUser.Id }, createdUser);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    // 5. PUT: api/users/{id}
    [HttpPut(UserRoutes.Update)]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserDto dto)
    {
        var updatedUser = await _userService.UpdateUserAsync(id, dto);
        if (updatedUser == null)
            return NotFound(new { message = "User not found" });

        return Ok(updatedUser);
    }

    // 6. DELETE: api/users/{id}
    [HttpDelete(UserRoutes.Delete)]
    public async Task<IActionResult> DeleteUser(int id)
    {
        var success = await _userService.DeleteUserAsync(id);
        if (!success)
            return NotFound(new { message = "User not found" });

        return Ok(new { message = "User deleted successfully" });
    }

    // 7. PUT: api/users/{id}/activate
    [HttpPut(UserRoutes.Activate)]
    public async Task<IActionResult> ActivateUser(int id)
    {
        var success = await _userService.ChangeStatusAsync(id, "ACTIVE");
        if (!success) return NotFound(new { message = "User not found" });

        return Ok(new { message = "User activated successfully" });
    }

    // 8. PUT: api/users/{id}/deactivate
    [HttpPut(UserRoutes.Deactivate)]
    public async Task<IActionResult> DeactivateUser(int id)
    {
        var success = await _userService.ChangeStatusAsync(id, "INACTIVE");
        if (!success) return NotFound(new { message = "User not found" });

        return Ok(new { message = "User deactivated successfully" });
    }

    // 9. PUT: api/users/{id}/block
    [HttpPut(UserRoutes.Block)]
    public async Task<IActionResult> BlockUser(int id)
    {
        var success = await _userService.ChangeStatusAsync(id, "BLOCKED");
        if (!success) return NotFound(new { message = "User not found" });

        return Ok(new { message = "User blocked successfully" });
    }

    // 10. PUT: api/users/{id}/role
    [HttpPut(UserRoutes.ChangeRole)]
    public async Task<IActionResult> ChangeRole(int id, [FromBody] ChangeRoleDto dto)
    {
        try
        {
            var updated = await _userService.ChangeRoleAsync(id, dto.Role);
            if (updated == null)
                return NotFound(new { message = "User not found" });

            return Ok(updated);
        }
        catch (BadHttpRequestException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}