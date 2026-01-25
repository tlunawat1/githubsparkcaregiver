using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.DTOs;
using ParentalCareApi.Hubs;
using ParentalCareApi.Models;
using ParentalCareApi.Services;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RemindersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly INotificationService _notificationService;
    private readonly ILogger<RemindersController> _logger;

    public RemindersController(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationService notificationService,
        ILogger<RemindersController> logger)
    {
        _context = context;
        _hubContext = hubContext;
        _notificationService = notificationService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<List<ReminderDto>>> GetReminders([FromQuery] string? dependentId = null)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        IQueryable<Reminder> query = _context.Reminders
            .Include(r => r.Creator)
            .Include(r => r.Dependent)
            .Where(r => r.IsActive);

        if (userRole == "caregiver")
        {
            if (!string.IsNullOrEmpty(dependentId))
            {
                // Verify caregiver has relationship with this dependent
                var hasRelationship = await _context.CareRelationships.AnyAsync(
                    cr => cr.CaregiverId == userId &&
                          cr.DependentId == dependentId &&
                          cr.Status == "active");

                if (!hasRelationship)
                    return Forbid();

                query = query.Where(r => r.DependentId == dependentId);
            }
            else
            {
                // Get all reminders created by this caregiver
                query = query.Where(r => r.CreatorId == userId);
            }
        }
        else
        {
            // Dependent sees their own reminders
            query = query.Where(r => r.DependentId == userId);
        }

        var reminders = await query.OrderByDescending(r => r.CreatedAt).ToListAsync();

        return Ok(reminders.Select(MapToDto).ToList());
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ReminderDto>> GetReminder(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        var reminder = await _context.Reminders
            .Include(r => r.Creator)
            .Include(r => r.Dependent)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (reminder == null)
            return NotFound(new { message = "Reminder not found" });

        // Verify access
        if (userRole == "caregiver")
        {
            if (reminder.CreatorId != userId)
            {
                var hasRelationship = await _context.CareRelationships.AnyAsync(
                    cr => cr.CaregiverId == userId &&
                          cr.DependentId == reminder.DependentId &&
                          cr.Status == "active");

                if (!hasRelationship)
                    return Forbid();
            }
        }
        else if (reminder.DependentId != userId)
        {
            return Forbid();
        }

        return Ok(MapToDto(reminder));
    }

    [HttpPost]
    public async Task<ActionResult<ReminderDto>> CreateReminder([FromBody] CreateReminderRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        // Verify caregiver role for creating reminders
        if (userRole != "caregiver")
            return Forbid();

        // Verify relationship with dependent
        var hasRelationship = await _context.CareRelationships.AnyAsync(
            cr => cr.CaregiverId == userId &&
                  cr.DependentId == request.DependentId &&
                  cr.Status == "active");

        if (!hasRelationship)
            return BadRequest(new { message = "You don't have an active relationship with this dependent" });

        var reminder = new Reminder
        {
            Id = Guid.NewGuid().ToString(),
            CreatorId = userId,
            DependentId = request.DependentId,
            Title = request.Title,
            Description = request.Description,
            VoiceNoteUrl = request.VoiceNoteUrl,
            RepeatPattern = request.RepeatPattern,
            RepeatDays = request.RepeatDays,
            Hour = request.Hour,
            Minute = request.Minute,
            Priority = request.Priority,
            IsActive = true,
            StartDate = request.StartDate ?? DateTime.UtcNow.Date,
            EndDate = request.EndDate,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Reminders.Add(reminder);
        await _context.SaveChangesAsync();

        // Reload with navigation properties
        reminder = await _context.Reminders
            .Include(r => r.Creator)
            .Include(r => r.Dependent)
            .FirstOrDefaultAsync(r => r.Id == reminder.Id);

        _logger.LogInformation("Reminder created: {Id} for dependent {DependentId}", reminder!.Id, reminder.DependentId);

        // Notify dependent via SignalR
        await _hubContext.Clients.User(request.DependentId).SendAsync("ReminderCreated", MapToDto(reminder));

        // Send push notification
        var dependent = await _context.Users.FindAsync(request.DependentId);
        if (!string.IsNullOrEmpty(dependent?.DeviceToken))
        {
            var creator = await _context.Users.FindAsync(userId);
            await _notificationService.SendPushNotificationAsync(
                dependent.DeviceToken,
                "New Reminder",
                $"{creator?.Name ?? "Your caregiver"} created a reminder: {reminder.Title}",
                new Dictionary<string, string>
                {
                    { "type", "reminder_created" },
                    { "reminderId", reminder.Id }
                }
            );
        }

        return CreatedAtAction(nameof(GetReminder), new { id = reminder.Id }, MapToDto(reminder));
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<ReminderDto>> UpdateReminder(string id, [FromBody] UpdateReminderRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var reminder = await _context.Reminders
            .Include(r => r.Creator)
            .Include(r => r.Dependent)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (reminder == null)
            return NotFound(new { message = "Reminder not found" });

        // Only creator can update
        if (reminder.CreatorId != userId)
            return Forbid();

        if (!string.IsNullOrWhiteSpace(request.Title))
            reminder.Title = request.Title;

        if (request.Description != null)
            reminder.Description = request.Description;

        if (request.VoiceNoteUrl != null)
            reminder.VoiceNoteUrl = request.VoiceNoteUrl;

        if (!string.IsNullOrWhiteSpace(request.RepeatPattern))
            reminder.RepeatPattern = request.RepeatPattern;

        if (request.RepeatDays != null)
            reminder.RepeatDays = request.RepeatDays;

        if (request.Hour.HasValue)
            reminder.Hour = request.Hour.Value;

        if (request.Minute.HasValue)
            reminder.Minute = request.Minute.Value;

        if (!string.IsNullOrWhiteSpace(request.Priority))
            reminder.Priority = request.Priority;

        if (request.IsActive.HasValue)
            reminder.IsActive = request.IsActive.Value;

        if (request.StartDate.HasValue)
            reminder.StartDate = request.StartDate.Value;

        if (request.EndDate.HasValue)
            reminder.EndDate = request.EndDate.Value;

        reminder.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Reminder updated: {Id}", id);

        // Notify dependent via SignalR
        await _hubContext.Clients.User(reminder.DependentId).SendAsync("ReminderUpdated", MapToDto(reminder));

        return Ok(MapToDto(reminder));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteReminder(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var reminder = await _context.Reminders.FindAsync(id);

        if (reminder == null)
            return NotFound(new { message = "Reminder not found" });

        // Only creator can delete
        if (reminder.CreatorId != userId)
            return Forbid();

        // Soft delete
        reminder.IsActive = false;
        reminder.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Reminder deleted: {Id}", id);

        // Notify dependent via SignalR
        await _hubContext.Clients.User(reminder.DependentId).SendAsync("ReminderDeleted", new { reminderId = id });

        return Ok(new { message = "Reminder deleted" });
    }

    private static ReminderDto MapToDto(Reminder r)
    {
        return new ReminderDto(
            r.Id,
            r.CreatorId,
            r.DependentId,
            r.Title,
            r.Description,
            r.VoiceNoteUrl,
            r.RepeatPattern,
            r.RepeatDays,
            r.Hour,
            r.Minute,
            r.Priority,
            r.IsActive,
            r.StartDate,
            r.EndDate,
            r.CreatedAt,
            r.UpdatedAt,
            r.Creator?.Name,
            r.Dependent?.Name
        );
    }
}
