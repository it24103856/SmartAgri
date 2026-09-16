using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using SmartAgri.Api.Data;
using SmartAgri.Api.DTOs;
using SmartAgri.Api.Models;

namespace SmartAgri.Api.Services;

public sealed class PasswordResetService
{
    private readonly ApplicationDbContext _db;
    private readonly EmailService _email;
    private readonly byte[] _hashKey;

    public PasswordResetService(
        ApplicationDbContext db,
        EmailService email,
        IConfiguration configuration)
    {
        _db = db;
        _email = email;

        var configuredKey = configuration["PasswordReset:HashKey"]
            ?? throw new InvalidOperationException(
                "PasswordReset:HashKey is missing.");

        _hashKey = Convert.FromBase64String(configuredKey);

        if (_hashKey.Length < 32)
        {
            throw new InvalidOperationException(
                "PasswordReset:HashKey must contain at least 32 bytes.");
        }
    }

    // Called by the background email worker.
    public async Task SendCodeAsync(
        string email,
        CancellationToken cancellationToken)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();

        string recipient;
        string code;
        string savedHash;
        int userId;

        await using (var transaction =
            await _db.Database.BeginTransactionAsync(cancellationToken))
        {
            var user = await LockUserAsync(
                normalizedEmail,
                cancellationToken);

            if (user is null || user.Status != "ACTIVE")
                return;

            var now = DateTime.UtcNow;
            RefreshWindow(user, now);

            if (user.PasswordResetSendCount >= 5 ||
                user.PasswordResetFailedAttempts >= 5)
                return;

            if (user.PasswordResetLastSentAt is DateTime previous &&
                now - previous < TimeSpan.FromSeconds(60))
                return;

            code = RandomNumberGenerator
                .GetInt32(0, 100_000_000)
                .ToString("D8", CultureInfo.InvariantCulture);

            userId = user.Id;
            recipient = user.Email;
            savedHash = HashCode(userId, code);

            user.PasswordResetHash = savedHash;
            user.PasswordResetExpiresAt = now.AddMinutes(10);
            user.PasswordResetLastSentAt = now;
            user.PasswordResetSendCount++;

            // Deliberately do not reset failed attempts on resend.
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }

        try
        {
            await _email.SendAsync(
                recipient,
                "SmartAgri password reset code",
                $"Your SmartAgri password reset code is: {code}\n\n" +
                "This code expires in 10 minutes and can be used once.\n" +
                "If you did not request this, ignore this email.\n" +
                "Do not share this code with anyone.",
                cancellationToken);
        }
        catch
        {
            // Invalidate only this failed delivery's code.
            // Never erase a newer code or roll back a completed reset.
            await _db.Users
                .Where(user =>
                    user.Id == userId &&
                    user.PasswordResetHash == savedHash)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(
                            user => user.PasswordResetHash,
                            (string?)null)
                        .SetProperty(
                            user => user.PasswordResetExpiresAt,
                            (DateTime?)null),
                    CancellationToken.None);

            throw;
        }
    }

    public async Task<bool> ResetAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        // BCrypt has a 72-byte input limit.
        if (Encoding.UTF8.GetByteCount(request.NewPassword) > 72)
        {
            throw new BadHttpRequestException(
                "Password is too long in UTF-8 bytes.", 400);
        }

        var normalizedEmail = request.Email.Trim().ToLowerInvariant();

        await using var transaction =
            await _db.Database.BeginTransactionAsync(cancellationToken);

        var user = await LockUserAsync(
            normalizedEmail,
            cancellationToken);

        if (user is null || user.Status != "ACTIVE")
            return false;

        var now = DateTime.UtcNow;
        RefreshWindow(user, now);

        if (user.PasswordResetFailedAttempts >= 5)
            return false;

        if (user.PasswordResetHash is null ||
            user.PasswordResetExpiresAt is not DateTime expiresAt ||
            expiresAt <= now)
            return false;

        var candidate = Convert.FromHexString(
            HashCode(user.Id, request.Code));

        var expected = Convert.FromHexString(
            user.PasswordResetHash);

        if (!CryptographicOperations.FixedTimeEquals(candidate, expected))
        {
            user.PasswordResetFailedAttempts++;

            if (user.PasswordResetFailedAttempts >= 5)
            {
                user.PasswordResetHash = null;
                user.PasswordResetExpiresAt = null;
            }

            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return false;
        }

        user.PasswordHash =
            BCrypt.Net.BCrypt.HashPassword(request.NewPassword);

        // Invalidate every JWT issued before this reset.
        user.SessionStamp = Guid.NewGuid();
        user.UpdatedAt = now;

        // Consume the reset code in the same transaction.
        user.PasswordResetHash = null;
        user.PasswordResetExpiresAt = null;

        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return true;
    }

    private async Task<User?> LockUserAsync(
        string normalizedEmail,
        CancellationToken cancellationToken)
    {
        // PostgreSQL row lock serializes reset/resend attempts.
        // Interpolation is parameterized by EF Core.
        var matches = await _db.Users
            .FromSqlInterpolated($"""
                SELECT * FROM "Users"
                WHERE lower("Email") = {normalizedEmail}
                ORDER BY "Id"
                FOR UPDATE
                """)
            .ToListAsync(cancellationToken);

        // Do not choose an arbitrary account if legacy data has
        // duplicate emails differing only by capitalization.
        return matches.Count == 1 ? matches[0] : null;
    }

    private static void RefreshWindow(User user, DateTime now)
    {
        if (user.PasswordResetWindowStart is null ||
            now - user.PasswordResetWindowStart.Value >=
                TimeSpan.FromHours(1))
        {
            user.PasswordResetWindowStart = now;
            user.PasswordResetSendCount = 0;
            user.PasswordResetFailedAttempts = 0;
        }
    }

    private string HashCode(int userId, string code)
    {
        var input = Encoding.UTF8.GetBytes(
            $"{userId.ToString(CultureInfo.InvariantCulture)}:{code}");

        return Convert.ToHexString(
            HMACSHA256.HashData(_hashKey, input));
    }
}