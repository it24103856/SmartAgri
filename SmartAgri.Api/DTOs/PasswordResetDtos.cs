using System.ComponentModel.DataAnnotations;

namespace SmartAgri.Api.DTOs;

public sealed class ForgotPasswordRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = "";
}

public sealed class ResetPasswordRequest
{
    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = "";

    [Required, RegularExpression(@"^[0-9]{8}$")]
    public string Code { get; set; } = "";

    [Required, StringLength(64, MinimumLength = 12)]
    public string NewPassword { get; set; } = "";
}