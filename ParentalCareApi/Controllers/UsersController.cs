using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.DTOs;
using ParentalCareApi.Services;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<UsersController> _logger;
    private readonly INotificationJobService _notificationJobService;

    public UsersController(
        AppDbContext context,
        ILogger<UsersController> logger,
        INotificationJobService notificationJobService)
    {
        _context = context;
        _logger = logger;
        _notificationJobService = notificationJobService;
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
            user.Timezone,
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

        // Check if timezone is being changed
        var oldTimezone = user.Timezone;
        var timezoneChanged = !string.IsNullOrWhiteSpace(request.Timezone) && request.Timezone != oldTimezone;

        if (!string.IsNullOrWhiteSpace(request.Timezone))
            user.Timezone = request.Timezone;

        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // If timezone changed, recalculate all pending reminder instances for this user
        if (timezoneChanged)
        {
            await RecalculatePendingInstancesAsync(userId, request.Timezone!);
        }

        return Ok(new UserDto(
            user.Id,
            user.Name,
            user.Email,
            user.Role,
            user.PhoneNumber,
            user.UniqueCode,
            user.AvatarUrl,
            user.EmailVerified,
            user.Timezone,
            user.CreatedAt,
            user.LastLoginAt
        ));
    }

    private async Task RecalculatePendingInstancesAsync(string userId, string newTimezone)
    {
        // Get all pending instances for reminders where this user is the dependent
        var instances = await _context.ReminderInstances
            .Include(i => i.Reminder)
            .Where(i => i.Reminder.DependentId == userId
                     && i.Status == "pending"
                     && i.ScheduledTime > DateTime.UtcNow)
            .ToListAsync();

        if (instances.Count == 0)
        {
            _logger.LogInformation("No pending instances found for user {UserId} to recalculate", userId);
            return;
        }

        var reminderIds = new HashSet<string>();

        foreach (var instance in instances)
        {
            // Recalculate UTC time using new timezone
            var newScheduledTime = NotificationJobService.ConvertToUtc(
                instance.Reminder.Hour,
                instance.Reminder.Minute,
                instance.ScheduledTime.Date,
                newTimezone
            );
            instance.ScheduledTime = newScheduledTime;
            reminderIds.Add(instance.ReminderId);
        }

        await _context.SaveChangesAsync();

        // Reschedule Hangfire notification jobs for each affected reminder
        foreach (var reminderId in reminderIds)
        {
            await _notificationJobService.RescheduleReminderNotificationsAsync(reminderId);
        }

        _logger.LogInformation(
            "Recalculated {InstanceCount} instances for {ReminderCount} reminders after timezone change to {Timezone} for user {UserId}",
            instances.Count, reminderIds.Count, newTimezone, userId);
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
            user.AvatarUrl,
            user.Email,
            user.PhoneNumber
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
            user.AvatarUrl,
            user.Email,
            user.PhoneNumber
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
            user.AvatarUrl,
            user.Email,
            user.PhoneNumber
        ));
    }

    /// <summary>
    /// Update a linked user's name (caregiver can update dependent's name only)
    /// </summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<UserSearchResult>> UpdateLinkedUser(string id, [FromBody] UpdateLinkedUserRequest request)
    {
        var currentUserId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var currentUserRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (currentUserId == null)
            return Unauthorized();

        // Only caregivers can update linked users
        if (currentUserRole != "caregiver")
            return Forbid();

        // Verify an active relationship exists between the caregiver and the target user
        var relationship = await _context.CareRelationships
            .FirstOrDefaultAsync(r =>
                r.CaregiverId == currentUserId &&
                r.DependentId == id &&
                r.Status == "active");

        if (relationship == null)
            return Forbid();

        var user = await _context.Users.FindAsync(id);
        if (user == null)
            return NotFound(new { message = "User not found" });

        // Only allow updating the name
        if (!string.IsNullOrWhiteSpace(request.Name))
            user.Name = request.Name;

        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Caregiver {CaregiverId} updated name for dependent {DependentId}", currentUserId, id);

        return Ok(new UserSearchResult(
            user.Id,
            user.Name,
            user.Role,
            user.UniqueCode,
            user.AvatarUrl,
            user.Email,
            user.PhoneNumber
        ));
    }
}
