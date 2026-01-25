using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.DTOs;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<UsersController> _logger;

    public UsersController(AppDbContext context, ILogger<UsersController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet("me")]
    public async Task<ActionResult<UserDto>> GetCurrentUser()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null)
            return Unauthorized();

        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            return NotFound(new { message = "User not found" });

        return Ok(new UserDto(
            user.Id,
            user.Name,
            user.Email,
            user.Role,
            user.PhoneNumber,
            user.UniqueCode,
            user.AvatarUrl,
            user.EmailVerified,
            user.CreatedAt,
            user.LastLoginAt
        ));
    }

    [HttpPut("me")]
    public async Task<ActionResult<UserDto>> UpdateCurrentUser([FromBody] UpdateUserRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null)
            return Unauthorized();

        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            return NotFound(new { message = "User not found" });

        if (!string.IsNullOrWhiteSpace(request.Name))
            user.Name = request.Name;

        if (request.PhoneNumber != null)
            user.PhoneNumber = request.PhoneNumber;

        if (request.AvatarUrl != null)
            user.AvatarUrl = request.AvatarUrl;

        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new UserDto(
            user.Id,
            user.Name,
            user.Email,
            user.Role,
            user.PhoneNumber,
            user.UniqueCode,
            user.AvatarUrl,
            user.EmailVerified,
            user.CreatedAt,
            user.LastLoginAt
        ));
    }

    [HttpGet("code/{code}")]
    public async Task<ActionResult<UserSearchResult>> FindByUniqueCode(string code)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.UniqueCode == code.ToUpperInvariant());

        if (user == null)
            return NotFound(new { message = "User not found" });

        return Ok(new UserSearchResult(
            user.Id,
            user.Name,
            user.Role,
            user.UniqueCode,
            user.AvatarUrl
        ));
    }

    [HttpGet("email/{email}")]
    public async Task<ActionResult<UserSearchResult>> FindByEmail(string email)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.Email == email.ToLowerInvariant());

        if (user == null)
            return NotFound(new { message = "User not found" });

        return Ok(new UserSearchResult(
            user.Id,
            user.Name,
            user.Role,
            user.UniqueCode,
            user.AvatarUrl
        ));
    }

    [HttpPut("device-token")]
    public async Task<IActionResult> UpdateDeviceToken([FromBody] UpdateDeviceTokenRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null)
            return Unauthorized();

        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            return NotFound(new { message = "User not found" });

        user.DeviceToken = request.DeviceToken;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Device token updated for user {UserId}", userId);

        return Ok(new { message = "Device token updated" });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<UserSearchResult>> GetById(string id)
    {
        var user = await _context.Users.FindAsync(id);

        if (user == null)
            return NotFound(new { message = "User not found" });

        return Ok(new UserSearchResult(
            user.Id,
            user.Name,
            user.Role,
            user.UniqueCode,
            user.AvatarUrl
        ));
    }
}
