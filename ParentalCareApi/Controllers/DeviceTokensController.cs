using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.DTOs;
using ParentalCareApi.Models;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/device-tokens")]
[Authorize]
public class DeviceTokensController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<DeviceTokensController> _logger;

    public DeviceTokensController(AppDbContext context, ILogger<DeviceTokensController> logger)
    {
        _context = context;
        _logger = logger;
    }

    private string GetUserId() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value
        ?? throw new UnauthorizedAccessException("User not authenticated");

    [HttpPost]
    public async Task<ActionResult<DeviceTokenDto>> RegisterToken([FromBody] RegisterDeviceTokenRequest request)
    {
        var userId = GetUserId();

        // Check if token already exists
        var existingToken = await _context.UserDeviceTokens
            .FirstOrDefaultAsync(t => t.Token == request.Token);

        if (existingToken != null)
        {
            // Update existing token
            existingToken.UserId = userId;
            existingToken.Platform = request.Platform;
            existingToken.TokenType = string.IsNullOrWhiteSpace(request.TokenType) ? "fcm" : request.TokenType;
            existingToken.DeviceName = request.DeviceName;
            existingToken.AppVersion = request.AppVersion;
            existingToken.IsValid = true;
            existingToken.LastUsedAt = DateTime.UtcNow;
            existingToken.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            _logger.LogInformation("Updated device token for user {UserId}", userId);

            return Ok(MapToDto(existingToken));
        }

        // Create new token
        var deviceToken = new UserDeviceToken
        {
            UserId = userId,
            Token = request.Token,
            Platform = request.Platform,
            TokenType = string.IsNullOrWhiteSpace(request.TokenType) ? "fcm" : request.TokenType,
            DeviceName = request.DeviceName,
            AppVersion = request.AppVersion,
            IsValid = true,
            LastUsedAt = DateTime.UtcNow
        };

        _context.UserDeviceTokens.Add(deviceToken);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Registered new device token for user {UserId}", userId);

        return CreatedAtAction(nameof(GetMyTokens), null, MapToDto(deviceToken));
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<DeviceTokenDto>>> GetMyTokens()
    {
        var userId = GetUserId();

        var tokens = await _context.UserDeviceTokens
            .Where(t => t.UserId == userId && t.IsValid)
            .OrderByDescending(t => t.LastUsedAt)
            .ToListAsync();

        return Ok(tokens.Select(MapToDto));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> RemoveToken(string id)
    {
        var userId = GetUserId();

        var token = await _context.UserDeviceTokens
            .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);

        if (token == null)
        {
            return NotFound();
        }

        _context.UserDeviceTokens.Remove(token);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Removed device token {TokenId} for user {UserId}", id, userId);

        return NoContent();
    }

    [HttpPost("invalidate")]
    public async Task<IActionResult> InvalidateToken([FromBody] InvalidateDeviceTokenRequest request)
    {
        var userId = GetUserId();

        var token = await _context.UserDeviceTokens
            .FirstOrDefaultAsync(t => t.Token == request.Token && t.UserId == userId);

        if (token != null)
        {
            token.IsValid = false;
            token.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            _logger.LogInformation("Invalidated device token for user {UserId}", userId);
        }

        return NoContent();
    }

    [HttpPost("logout")]
    public async Task<IActionResult> LogoutDevice([FromBody] InvalidateDeviceTokenRequest request)
    {
        var userId = GetUserId();

        // Invalidate the specific device token
        var token = await _context.UserDeviceTokens
            .FirstOrDefaultAsync(t => t.Token == request.Token && t.UserId == userId);

        if (token != null)
        {
            token.IsValid = false;
            token.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        return NoContent();
    }

    private static DeviceTokenDto MapToDto(UserDeviceToken token)
    {
        return new DeviceTokenDto(
            token.Id,
            token.Token[..Math.Min(20, token.Token.Length)] + "...", // Truncate for security
            token.Platform,
            token.TokenType,
            token.DeviceName,
            token.AppVersion,
            token.IsValid,
            token.LastUsedAt,
            token.CreatedAt
        );
    }
}
