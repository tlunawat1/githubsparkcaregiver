using System.Security.Claims;
using Hangfire;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NodaTime;
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
    private readonly INotificationJobService _notificationJobService;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<RemindersController> _logger;

    public RemindersController(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationService notificationService,
        INotificationJobService notificationJobService,
        IServiceScopeFactory scopeFactory,
        ILogger<RemindersController> logger)
    {
        _context = context;
        _hubContext = hubContext;
        _notificationService = notificationService;
        _notificationJobService = notificationJobService;
        _scopeFactory = scopeFactory;
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

        // Generate instances based on repeat pattern (no longer schedules notification jobs inline)
        var instances = await GenerateInstancesForReminder(reminder);

        var reminderDto = MapToDto(reminder);
        var dependentId = request.DependentId;
        var reminderId = reminder.Id;

        // Enqueue background job to schedule all notification jobs (decoupled from HTTP request)
        BackgroundJob.Enqueue<INotificationJobService>(x => x.ProcessReminderNotificationsAsync(reminderId));

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // SignalR: Send ReminderCreated to dependent via their user group (created on connect)
        var dependentGroupName = $"user:{dependentId}";
        _logger.LogInformation("Sending ReminderCreated SignalR to group '{GroupName}' for dependent {DependentId}", dependentGroupName, dependentId);
        await _hubContext.Clients.Group(dependentGroupName).SendAsync("ReminderCreated", reminderDto);
        _logger.LogInformation("ReminderCreated SignalR sent to group '{GroupName}'", dependentGroupName);

        // SignalR: Notify about created instances - MUST await to ensure delivery
        var caregiverGroupNames = caregiverIds.Select(id => $"user:{id}").ToList();
        _logger.LogInformation("Sending {Count} InstanceCreated SignalR to groups: dependent='{DependentGroup}', caregivers=[{CaregiverGroups}]",
            instances.Count, dependentGroupName, string.Join(", ", caregiverGroupNames));
        foreach (var instance in instances)
        {
            var instanceDto = new
            {
                instance.Id,
                instance.ReminderId,
                instance.ScheduledTime,
                instance.Status,
                instance.CompletedAt,
                instance.SnoozedUntil,
                instance.EscalationLevel,
                instance.CreatedAt,
                ReminderTitle = reminder.Title,
                ReminderDescription = reminder.Description,
                VoiceNoteUrl = reminder.VoiceNoteUrl,
                Priority = reminder.Priority
            };
            await _hubContext.SendInstanceCreatedAsync(dependentId, instanceDto, caregiverIds);
        }
        _logger.LogInformation("All InstanceCreated SignalR notifications sent successfully");

        // Fire-and-forget: Push notification (external Firebase API call - slow)
        // Use IServiceScopeFactory instead of HttpContext.RequestServices to avoid ObjectDisposedException
        var scopeFactory = _scopeFactory;
        var notificationService = _notificationService;
        var reminderTitle = reminder.Title;
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

                var dependent = await context.Users.FindAsync(dependentId);
                if (!string.IsNullOrEmpty(dependent?.DeviceToken))
                {
                    var creator = await context.Users.FindAsync(userId);
                    await notificationService.SendPushNotificationAsync(
                        dependent.DeviceToken,
                        "New Reminder",
                        $"{creator?.Name ?? "Your caregiver"} created a reminder: {reminderTitle}",
                        new Dictionary<string, string>
                        {
                            { "type", "reminder_created" },
                            { "reminderId", reminderId }
                        }
                    );
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send push notification for reminder {ReminderId}", reminderId);
            }
        });

        return CreatedAtAction(nameof(GetReminder), new { id = reminder.Id }, reminderDto);
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

        // Track if time changed to update instances
        var timeChanged = false;
        var oldHour = reminder.Hour;
        var oldMinute = reminder.Minute;

        if (request.Hour.HasValue)
        {
            if (reminder.Hour != request.Hour.Value)
                timeChanged = true;
            reminder.Hour = request.Hour.Value;
        }

        if (request.Minute.HasValue)
        {
            if (reminder.Minute != request.Minute.Value)
                timeChanged = true;
            reminder.Minute = request.Minute.Value;
        }

        if (!string.IsNullOrWhiteSpace(request.Priority))
            reminder.Priority = request.Priority;

        if (request.IsActive.HasValue)
            reminder.IsActive = request.IsActive.Value;

        if (request.StartDate.HasValue)
            reminder.StartDate = request.StartDate.Value;

        if (request.EndDate.HasValue)
            reminder.EndDate = request.EndDate.Value;

        reminder.UpdatedAt = DateTime.UtcNow;

        // Update all instances if time changed
        var updatedInstances = new List<ReminderInstance>();

        if (timeChanged)
        {
            // Get dependent's timezone for proper UTC conversion
            var dependent = await _context.Users.FindAsync(reminder.DependentId);
            var timezone = dependent?.Timezone ?? "UTC";

            // Get all instances for this reminder (today and future)
            var today = DateTime.UtcNow.Date;
            var instances = await _context.ReminderInstances
                .Where(i => i.ReminderId == id && i.ScheduledTime.Date >= today)
                .ToListAsync();

            var now = DateTime.UtcNow;

            foreach (var instance in instances)
            {
                // Update the scheduled time with proper timezone conversion
                var date = instance.ScheduledTime.Date;
                var newScheduledTime = NotificationJobService.ConvertToUtc(
                    reminder.Hour,
                    reminder.Minute,
                    date,
                    timezone
                );
                instance.ScheduledTime = newScheduledTime;

                // If new time is in the future, reset status to pending
                if (newScheduledTime > now)
                {
                    if (instance.Status != "pending")
                    {
                        instance.Status = "pending";
                        instance.CompletedAt = null;
                        instance.SnoozedUntil = null;
                        instance.EscalationLevel = 0;
                        _logger.LogInformation("Reset instance {InstanceId} to pending (new time {NewTime} is in future)", instance.Id, newScheduledTime);
                    }
                }

                updatedInstances.Add(instance);
            }

            _logger.LogInformation("Updated {Count} instances with new time for reminder {Id}", instances.Count, id);
        }

        await _context.SaveChangesAsync();

        // Enqueue background job to reschedule notification jobs (decoupled from HTTP request)
        if (timeChanged)
        {
            BackgroundJob.Enqueue<INotificationJobService>(x => x.RescheduleReminderNotificationsAsync(id));
        }

        _logger.LogInformation("Reminder updated: {Id}", id);

        var reminderDto = MapToDto(reminder);
        var dependentId = reminder.DependentId;

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // SignalR: Send ReminderUpdated to dependent via their user group
        _logger.LogInformation("Sending ReminderUpdated SignalR to dependent {DependentId}", dependentId);
        await _hubContext.Clients.Group($"user:{dependentId}").SendAsync("ReminderUpdated", reminderDto);
        _logger.LogInformation("ReminderUpdated SignalR sent successfully to dependent {DependentId}", dependentId);

        // SignalR: Notify about updated instances - MUST await to ensure delivery
        if (updatedInstances.Count > 0)
        {
            _logger.LogInformation("Sending {Count} InstanceStatusChanged SignalR notifications to dependent {DependentId} and {CaregiverCount} caregivers",
                updatedInstances.Count, dependentId, caregiverIds.Count);
            foreach (var instance in updatedInstances)
            {
                var instanceDto = new
                {
                    instance.Id,
                    instance.ReminderId,
                    instance.ScheduledTime,
                    instance.Status,
                    instance.CompletedAt,
                    instance.SnoozedUntil,
                    instance.EscalationLevel,
                    instance.CreatedAt,
                    ReminderTitle = reminder.Title,
                    ReminderDescription = reminder.Description,
                    VoiceNoteUrl = reminder.VoiceNoteUrl,
                    Priority = reminder.Priority
                };
                await _hubContext.SendInstanceStatusChangedAsync(dependentId, instanceDto, caregiverIds);
            }
            _logger.LogInformation("All InstanceStatusChanged SignalR notifications sent successfully");
        }

        return Ok(reminderDto);
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

        // SignalR notification via user group - must await to ensure delivery
        await _hubContext.Clients.Group($"user:{reminder.DependentId}").SendAsync("ReminderDeleted", new { reminderId = id });

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

    /// <summary>
    /// Generates ReminderInstance records based on the reminder's repeat pattern.
    /// Creates instances for a 7-day rolling window.
    /// Uses the dependent's timezone to correctly schedule notifications.
    /// </summary>
    private async Task<List<ReminderInstance>> GenerateInstancesForReminder(Reminder reminder)
    {
        var instances = new List<ReminderInstance>();

        // Get dependent's timezone for proper UTC conversion
        var dependent = await _context.Users.FindAsync(reminder.DependentId);
        var timezone = dependent?.Timezone ?? "UTC";

        // Calculate "today" in the dependent's timezone, not UTC
        var today = GetCurrentDateInTimezone(timezone);
        var startDate = reminder.StartDate.Date >= today ? reminder.StartDate.Date : today;
        var endDate = reminder.EndDate?.Date ?? today.AddDays(7);
        var windowEnd = today.AddDays(7);

        // Don't generate past the window or the reminder's end date
        endDate = endDate < windowEnd ? endDate : windowEnd;

        switch (reminder.RepeatPattern.ToLower())
        {
            case "once":
                // Create single instance for the start date
                if (reminder.StartDate.Date >= today && reminder.StartDate.Date <= windowEnd)
                {
                    _logger.LogInformation("=== TIMEZONE FIX: Creating 'once' instance - StartDate={StartDate}, Hour={Hour}, Min={Min}, Timezone={Tz} ===",
                        reminder.StartDate.Date, reminder.Hour, reminder.Minute, timezone);
                    var instance = CreateInstance(reminder, reminder.StartDate.Date, timezone);
                    _logger.LogInformation("=== TIMEZONE FIX: Created instance with ScheduledTime={ScheduledTime} ===", instance.ScheduledTime);
                    instances.Add(instance);
                }
                break;

            case "daily":
                // Create instances for each day in the window
                _logger.LogInformation("=== TIMEZONE FIX: Creating 'daily' instances - StartDate={StartDate}, EndDate={EndDate}, Today={Today}, Hour={Hour}, Min={Min}, Timezone={Tz} ===",
                    startDate, endDate, today, reminder.Hour, reminder.Minute, timezone);
                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    var inst = CreateInstance(reminder, date, timezone);
                    _logger.LogInformation("=== TIMEZONE FIX: Daily instance Date={Date} -> ScheduledTime={ScheduledTime} ===", date, inst.ScheduledTime);
                    instances.Add(inst);
                }
                break;

            case "weekly":
                // Create instances for the same day of week within the window
                var targetDayOfWeek = reminder.StartDate.DayOfWeek;
                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    if (date.DayOfWeek == targetDayOfWeek)
                    {
                        instances.Add(CreateInstance(reminder, date, timezone));
                    }
                }
                break;

            case "specific_days":
                // Parse RepeatDays JSON array like "[1,3,5]" for Mon, Wed, Fri
                // 0=Sunday, 1=Monday, ..., 6=Saturday
                if (!string.IsNullOrEmpty(reminder.RepeatDays))
                {
                    try
                    {
                        var days = System.Text.Json.JsonSerializer.Deserialize<int[]>(reminder.RepeatDays) ?? [];
                        for (var date = startDate; date <= endDate; date = date.AddDays(1))
                        {
                            if (days.Contains((int)date.DayOfWeek))
                            {
                                instances.Add(CreateInstance(reminder, date, timezone));
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to parse RepeatDays for reminder {ReminderId}", reminder.Id);
                    }
                }
                break;
        }

        if (instances.Count > 0)
        {
            _context.ReminderInstances.AddRange(instances);
            await _context.SaveChangesAsync();
            _logger.LogInformation("Created {Count} instances for reminder {ReminderId}", instances.Count, reminder.Id);
            // Note: Notification job scheduling is handled by ProcessReminderNotificationsAsync in background
        }

        return instances;
    }

    /// <summary>
    /// Creates a ReminderInstance with proper timezone conversion.
    /// The ScheduledTime is stored in UTC.
    /// </summary>
    private static ReminderInstance CreateInstance(Reminder reminder, DateTime date, string timezone)
    {
        // Convert local time to UTC using the dependent's timezone
        var scheduledTimeUtc = NotificationJobService.ConvertToUtc(
            reminder.Hour,
            reminder.Minute,
            date,
            timezone
        );

        return new ReminderInstance
        {
            Id = Guid.NewGuid().ToString(),
            ReminderId = reminder.Id,
            ScheduledTime = scheduledTimeUtc,
            Status = "pending",
            EscalationLevel = 0,
            CreatedAt = DateTime.UtcNow
        };
    }

    /// <summary>
    /// Gets the current date in the specified timezone.
    /// This is important for determining "today" from the user's perspective.
    /// </summary>
    private DateTime GetCurrentDateInTimezone(string timezone)
    {
        try
        {
            var tz = DateTimeZoneProviders.Tzdb.GetZoneOrNull(timezone);
            if (tz == null)
            {
                _logger.LogWarning("=== TIMEZONE FIX: Invalid timezone '{Timezone}', falling back to UTC date", timezone);
                return DateTime.UtcNow.Date;
            }

            var now = SystemClock.Instance.GetCurrentInstant();
            var zonedDateTime = now.InZone(tz);
            var localDate = new DateTime(zonedDateTime.Year, zonedDateTime.Month, zonedDateTime.Day);

            _logger.LogInformation("=== TIMEZONE FIX: UTC now={UtcNow}, Timezone={Tz}, LocalDate={LocalDate} ===",
                DateTime.UtcNow, timezone, localDate);

            return localDate;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "=== TIMEZONE FIX: Error getting local date for timezone {Timezone}", timezone);
            return DateTime.UtcNow.Date;
        }
    }
}
