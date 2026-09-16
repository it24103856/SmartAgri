using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Services;

namespace SmartAgri.Api.Controllers;

[ApiController]
[Route("api/auth")]
[AllowAnonymous]
[EnableRateLimiting("password-reset")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class PasswordResetController : ControllerBase
{
    private readonly PasswordResetQueue _queue;
    private readonly PasswordResetService _service;

    public PasswordResetController(
        PasswordResetQueue queue,
        PasswordResetService service)
    {
        _queue = queue;
        _service = service;
    }

    [HttpPost("forgot-password")]
    public IActionResult ForgotPassword(
        [FromBody] ForgotPasswordRequest request)
    {
        if (!_queue.TryAdd(request.Email.Trim()))
        {
            return StatusCode(503, new
            {
                message = "Email service is busy. Please try again later."
            });
        }

        return Accepted(new
        {
            message =
                "If this email belongs to an eligible account, " +
                "a reset code will be sent. Check your inbox and spam folder."
        });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var success = await _service.ResetAsync(
            request,
            cancellationToken);

        if (!success)
        {
            return BadRequest(new
            {
                message =
                    "The code is invalid, expired, or the attempt limit " +
                    "was reached. Request a new code or try again later."
            });
        }

        return Ok(new
        {
            message =
                "Password changed. Please sign in with your new password."
        });
    }
}