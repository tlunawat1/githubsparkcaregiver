using System.Security.Claims;
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
[Route("api/reminder-instances")]
[Authorize]
public class ReminderInstancesController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly INotificationJobService _notificationJobService;
    private readonly ILogger<ReminderInstancesController> _logger;
    private readonly IConfiguration _configuration;
    private readonly INotificationService _notificationService;

    public ReminderInstancesController(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationJobService notificationJobService,
        ILogger<ReminderInstancesController> logger,
        IConfiguration configuration,
        INotificationService notificationService)
    {
        _context = context;
        _hubContext = hubContext;
        _notificationJobService = notificationJobService;
        _logger = logger;
        _configuration = configuration;
        _notificationService = notificationService;
    }

    /// <summary>
    /// Get reminder instances for a date and dependent
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetInstances(
        [FromQuery] string? dependentId,
        [FromQuery] DateTime? date)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var query = _context.ReminderInstances
            .Include(i => i.Reminder)
            .AsQueryable();

        // Filter by dependent
        if (!string.IsNullOrEmpty(dependentId))
        {
            // Verify access
            if (userRole == "caregiver")
            {
                var hasRelationship = await _context.CareRelationships
                    .AnyAsync(r => r.CaregiverId == userId && r.DependentId == dependentId && r.Status == "active");

                if (!hasRelationship)
                {
                    return Forbid();
                }
            }
            else if (dependentId != userId)
            {
                return Forbid();
            }

            // Log dependent's timezone for debugging
            var dependent = await _context.Users.FindAsync(dependentId);
            _logger.LogInformation("=== TIMEZONE DEBUG: Dependent {DependentId} has timezone: '{Timezone}' ===",
                dependentId, dependent?.Timezone ?? "NULL");

            query = query.Where(i => i.Reminder.DependentId == dependentId);
        }
        else if (userRole == "dependent")
        {
            // Dependents can only see their own instances
            // Log dependent's timezone for debugging
            var dependent = await _context.Users.FindAsync(userId);
            _logger.LogInformation("=== TIMEZONE DEBUG: Dependent {DependentId} has timezone: '{Timezone}' ===",
                userId, dependent?.Timezone ?? "NULL");

            query = query.Where(i => i.Reminder.DependentId == userId);
        }
        else
        {
            // Caregivers see instances for all their dependents
            var dependentIds = await _context.CareRelationships
                .Where(r => r.CaregiverId == userId && r.Status == "active")
                .Select(r => r.DependentId)
                .ToListAsync();

            query = query.Where(i => dependentIds.Contains(i.Reminder.DependentId));
        }

        // Filter by date - convert local date to UTC range using dependent's timezone
        if (date.HasValue)
        {
            // Get the target dependent's timezone for proper date conversion
            string? targetTimezone = null;
            if (!string.IsNullOrEmpty(dependentId))
            {
                var dep = await _context.Users.FindAsync(dependentId);
                targetTimezone = dep?.Timezone;
            }
            else if (userRole == "dependent")
            {
                var dep = await _context.Users.FindAsync(userId);
                targetTimezone = dep?.Timezone;
            }

            // Convert local date to UTC range
            var localDate = date.Value.Date;
            var (startOfDayUtc, endOfDayUtc) = ConvertLocalDateRangeToUtc(localDate, targetTimezone ?? "UTC");

            _logger.LogInformation("Filtering instances for local date {LocalDate} in timezone {Tz} -> UTC range: {Start} to {End}",
                localDate, targetTimezone ?? "UTC", startOfDayUtc, endOfDayUtc);

            query = query.Where(i => i.ScheduledTime >= startOfDayUtc && i.ScheduledTime < endOfDayUtc);
        }

        // Only get instances for active reminders
        query = query.Where(i => i.Reminder.IsActive);

        var instances = await query
            .OrderBy(i => i.ScheduledTime)
            .Select(i => MapToDto(i))
            .ToListAsync();

        _logger.LogInformation("=== GetInstances: Fetched {Count} instances, calling MarkOverdueInstancesAsMissedAsync ===", instances.Count);

        // Mark overdue pending instances as missed
        instances = await MarkOverdueInstancesAsMissedAsync(instances);

        _logger.LogInformation("=== GetInstances: After MarkOverdueInstancesAsMissedAsync, returning {Count} instances ===", instances.Count);

        return Ok(new { data = instances });
    }

    /// <summary>
    /// Get a single reminder instance
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetInstance(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var instance = await _context.ReminderInstances
            .Include(i => i.Reminder)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (instance == null)
        {
            return NotFound(new { message = "Instance not found" });
        }

        // Verify access
        var dependentId = instance.Reminder.DependentId;
        if (userRole == "caregiver")
        {
            var hasRelationship = await _context.CareRelationships
                .AnyAsync(r => r.CaregiverId == userId && r.DependentId == dependentId && r.Status == "active");

            if (!hasRelationship && instance.Reminder.CreatorId != userId)
            {
                return Forbid();
            }
        }
        else if (dependentId != userId)
        {
            return Forbid();
        }

        return Ok(MapToDto(instance));
    }

    /// <summary>
    /// Create a new reminder instance
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateInstance([FromBody] CreateInstanceRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var reminder = await _context.Reminders.FindAsync(request.ReminderId);
        if (reminder == null)
        {
            return NotFound(new { message = "Reminder not found" });
        }

        var instance = new ReminderInstance
        {
            ReminderId = request.ReminderId,
            ScheduledTime = request.ScheduledTime,
            Status = "pending",
            EscalationLevel = 0
        };

        _context.ReminderInstances.Add(instance);
        await _context.SaveChangesAsync();

        // Load the reminder for the DTO
        await _context.Entry(instance).Reference(i => i.Reminder).LoadAsync();

        var dto = MapToDto(instance);
        var instanceId = instance.Id;
        var scheduledTime = request.ScheduledTime;
        var dependentId = reminder.DependentId;

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // SignalR notifications - send to both dependent and caregivers by user ID
        await _hubContext.SendInstanceCreatedAsync(dependentId, dto, caregiverIds);

        // Fire-and-forget: Schedule notification jobs (slow Hangfire operation)
        _ = Task.Run(async () =>
        {
            try
            {
                await _notificationJobService.ScheduleNotificationJobsAsync(instanceId, scheduledTime);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to schedule notification jobs for instance {InstanceId}", instanceId);
            }
        });

        _logger.LogInformation("Created instance {InstanceId} for reminder {ReminderId}", instanceId, request.ReminderId);

        return CreatedAtAction(nameof(GetInstance), new { id = instanceId }, dto);
    }

    /// <summary>
    /// Mark an instance as completed
    /// </summary>
    [HttpPut("{id}/complete")]
    public async Task<IActionResult> MarkCompleted(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var instance = await _context.ReminderInstances
            .Include(i => i.Reminder)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (instance == null)
        {
            return NotFound(new { message = "Instance not found" });
        }

        // Verify the dependent owns this instance
        if (instance.Reminder.DependentId != userId)
        {
            return Forbid();
        }

        instance.Status = "completed";
        instance.CompletedAt = DateTime.UtcNow;

        // Save the critical state change immediately
        await _context.SaveChangesAsync();

        var dto = MapToDto(instance);
        var dependentId = instance.Reminder.DependentId;

        // Query caregivers directly from database to ensure SignalR delivery
        // (group membership is lost when caregivers disconnect/reconnect)
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        _logger.LogInformation("Sending InstanceStatusChanged for {InstanceId} to dependent {DependentId} and {CaregiverCount} caregivers",
            id, dependentId, caregiverIds.Count);

        // SignalR notifications - send to both dependent and caregivers by user ID
        await _hubContext.SendInstanceStatusChangedAsync(dependentId, dto, caregiverIds);

        // Fire-and-forget: Cancel notification jobs (slow Hangfire operation)
        _ = Task.Run(async () =>
        {
            try
            {
                await _notificationJobService.CancelNotificationJobsAsync(id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to cancel notification jobs for instance {InstanceId}", id);
            }
        });

        _logger.LogInformation("Instance {InstanceId} marked as completed", id);

        return Ok(dto);
    }

    /// <summary>
    /// Snooze an instance
    /// </summary>
    [HttpPut("{id}/snooze")]
    public async Task<IActionResult> SnoozeInstance(string id, [FromBody] SnoozeInstanceRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var instance = await _context.ReminderInstances
            .Include(i => i.Reminder)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (instance == null)
        {
            return NotFound(new { message = "Instance not found" });
        }

        // Verify the dependent owns this instance
        if (instance.Reminder.DependentId != userId)
        {
            return Forbid();
        }

        var snoozedUntilUtc = request.SnoozedUntil.Kind switch
        {
            DateTimeKind.Utc => request.SnoozedUntil,
            DateTimeKind.Local => request.SnoozedUntil.ToUniversalTime(),
            _ => DateTime.SpecifyKind(request.SnoozedUntil, DateTimeKind.Utc)
        };

        instance.Status = "snoozed";
        instance.SnoozedUntil = snoozedUntilUtc;
        instance.EscalationLevel = 0;
        await _context.SaveChangesAsync();

        var dto = MapToDto(instance);
        var dependentId = instance.Reminder.DependentId;

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // SignalR notifications - send to both dependent and caregivers by user ID
        await _hubContext.SendInstanceStatusChangedAsync(dependentId, dto, caregiverIds);

        // Fire-and-forget: Cancel existing notification jobs and reschedule from snooze time.
        // This prevents the original +5/+10 escalations (and auto-miss) from firing during the snooze window.
        _ = Task.Run(async () =>
        {
            try
            {
                await _notificationJobService.CancelNotificationJobsAsync(id);
                await _notificationJobService.ScheduleNotificationJobsAsync(id, snoozedUntilUtc);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to reschedule notification jobs for snoozed instance {InstanceId}", id);
            }
        });

        _logger.LogInformation("Instance {InstanceId} snoozed until {SnoozedUntilUtc} (UTC)", id, snoozedUntilUtc);

        return Ok(dto);
    }

    /// <summary>
    /// Mark an instance as missed
    /// </summary>
    [HttpPut("{id}/miss")]
    public async Task<IActionResult> MarkMissed(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var instance = await _context.ReminderInstances
            .Include(i => i.Reminder)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (instance == null)
        {
            return NotFound(new { message = "Instance not found" });
        }

        instance.Status = "missed";

        // Save the critical state change immediately
        await _context.SaveChangesAsync();

        var dto = MapToDto(instance);
        var dependentId = instance.Reminder.DependentId;

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // SignalR notifications - send to both dependent and caregivers by user ID
        await _hubContext.SendInstanceStatusChangedAsync(dependentId, dto, caregiverIds);

        // Fire-and-forget: Cancel notification jobs (slow Hangfire operation)
        _ = Task.Run(async () =>
        {
            try
            {
                await _notificationJobService.CancelNotificationJobsAsync(id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to cancel notification jobs for instance {InstanceId}", id);
            }
        });

        _logger.LogInformation("Instance {InstanceId} marked as missed", id);

        return Ok(dto);
    }

    /// <summary>
    /// Escalate an instance
    /// </summary>
    [HttpPut("{id}/escalate")]
    public async Task<IActionResult> EscalateInstance(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
        {
            return Unauthorized();
        }

        var instance = await _context.ReminderInstances
            .Include(i => i.Reminder)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (instance == null)
        {
            return NotFound(new { message = "Instance not found" });
        }

        if (instance.EscalationLevel >= 2)
        {
            return BadRequest(new { message = "Maximum escalation level reached" });
        }

        instance.EscalationLevel++;
        await _context.SaveChangesAsync();

        var dto = MapToDto(instance);
        var dependentId = instance.Reminder.DependentId;

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await _context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // SignalR notifications - send to both dependent and caregivers by user ID
        await _hubContext.SendInstanceStatusChangedAsync(dependentId, dto, caregiverIds);

        _logger.LogInformation("Instance {InstanceId} escalated to level {Level}", id, instance.EscalationLevel);

        return Ok(dto);
    }

    /// <summary>
    /// Marks overdue pending instances as missed and sends notifications
    /// </summary>
    private async Task<List<ReminderInstanceDto>> MarkOverdueInstancesAsMissedAsync(
        List<ReminderInstanceDto> instances)
    {
        _logger.LogInformation("=== MarkOverdueInstancesAsMissedAsync START ===");
        _logger.LogInformation("Total instances received: {Count}", instances.Count);

        var configuredGracePeriod = _configuration.GetValue<int>("Notifications:MissedGracePeriodMinutes", 5);
        var escalationDelay = _configuration.GetValue<int>("Notifications:EscalationDelayMinutes", 5);

        // IMPORTANT:
        // Reminder notifications are scheduled at: t (level 0), t+EscalationDelay (level 1), t+2*EscalationDelay (level 2).
        // If we mark instances as missed too early (e.g. after 5 minutes), the level-2 notification gets skipped because
        // NotificationJobService will not send notifications for instances with status "missed".
        //
        // To ensure the final escalation has a chance to run, enforce a minimum grace window that extends past the
        // final escalation time. Add a small buffer to avoid race conditions with slightly delayed job execution.
        var minGraceToAllowFinalEscalation = (escalationDelay * 2) + 1;
        var gracePeriod = Math.Max(configuredGracePeriod, minGraceToAllowFinalEscalation);
        var now = DateTime.UtcNow;
        var cutoffTime = now.AddMinutes(-gracePeriod);

        _logger.LogInformation(
            "Missed cutoff: configuredGrace={ConfiguredGrace}m, escalationDelay={EscalationDelay}m, effectiveGrace={EffectiveGrace}m, Now (UTC): {Now}, Cutoff time: {Cutoff}",
            configuredGracePeriod, escalationDelay, gracePeriod, now, cutoffTime);

        // Log all instances for debugging
        foreach (var inst in instances)
        {
            _logger.LogInformation("Instance {Id}: Status={Status}, ScheduledTime={ScheduledTime}, IsPastCutoff={IsPast}",
                inst.Id, inst.Status, inst.ScheduledTime, inst.ScheduledTime < cutoffTime);
        }

        // Find pending instances past grace period
        var overdueIds = instances
            .Where(i => i.Status == "pending" && i.ScheduledTime < cutoffTime)
            .Select(i => i.Id)
            .ToList();

        _logger.LogInformation("Found {Count} overdue pending instances", overdueIds.Count);

        if (!overdueIds.Any())
        {
            _logger.LogInformation("No overdue instances found, returning original list");
            return instances;
        }

        _logger.LogInformation("Overdue instance IDs: {Ids}", string.Join(", ", overdueIds));

        // Load and update database records
        var dbInstances = await _context.ReminderInstances
            .Include(i => i.Reminder)
                .ThenInclude(r => r.Dependent)
            .Where(i => overdueIds.Contains(i.Id) && i.Status == "pending")
            .ToListAsync();

        _logger.LogInformation("Loaded {Count} instances from DB that are still pending", dbInstances.Count);

        if (!dbInstances.Any())
        {
            _logger.LogInformation("No DB instances found (may have been updated already), returning original list");
            return instances;
        }

        // Group by dependent for notifications
        var instancesByDependent = dbInstances
            .GroupBy(i => i.Reminder.DependentId)
            .ToDictionary(g => g.Key, g => g.ToList());

        foreach (var instance in dbInstances)
        {
            _logger.LogInformation("Marking instance {Id} as missed (was: {OldStatus})", instance.Id, instance.Status);
            instance.Status = "missed";
        }
        await _context.SaveChangesAsync();
        _logger.LogInformation("Database updated successfully");

        // Rebuild result list with corrected statuses
        var updatedInstances = instances.Select(i =>
            overdueIds.Contains(i.Id)
                ? i with { Status = "missed" }
                : i
        ).ToList();

        _logger.LogInformation("=== Marked {Count} overdue instances as missed on fetch ===", dbInstances.Count);

        // Fire-and-forget: notifications and job cancellation
        _ = Task.Run(async () =>
        {
            try
            {
                foreach (var (dependentId, depInstances) in instancesByDependent)
                {
                    // Get caregivers for this dependent
                    var caregiverIds = await _context.CareRelationships
                        .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
                        .Select(cr => cr.CaregiverId)
                        .ToListAsync();

                    foreach (var instance in depInstances)
                    {
                        var dto = MapToDto(instance);

                        // SignalR notifications
                        await _hubContext.SendInstanceStatusChangedAsync(dependentId, dto, caregiverIds);

                        // Push notification to caregivers
                        foreach (var caregiverId in caregiverIds)
                        {
                            await _notificationService.SendToUserAsync(
                                caregiverId,
                                $"Missed: {instance.Reminder.Title}",
                                $"{instance.Reminder.Dependent?.Name ?? "Dependent"} missed their reminder",
                                new Dictionary<string, string>
                                {
                                    { "type", "missed_reminder" },
                                    { "instanceId", instance.Id },
                                    { "dependentId", dependentId }
                                });
                        }

                        // Cancel Hangfire jobs
                        await _notificationJobService.CancelNotificationJobsAsync(instance.Id);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send notifications for missed instances");
            }
        });

        return updatedInstances;
    }

    private static ReminderInstanceDto MapToDto(ReminderInstance instance)
    {
        // Explicitly mark all DateTime values as UTC so JSON serializer adds 'Z' suffix
        // This ensures Flutter's DateTime.parse() correctly identifies them as UTC
        return new ReminderInstanceDto(
            instance.Id,
            instance.ReminderId,
            DateTime.SpecifyKind(instance.ScheduledTime, DateTimeKind.Utc),
            instance.Status,
            instance.CompletedAt.HasValue
                ? DateTime.SpecifyKind(instance.CompletedAt.Value, DateTimeKind.Utc)
                : null,
            instance.SnoozedUntil.HasValue
                ? DateTime.SpecifyKind(instance.SnoozedUntil.Value, DateTimeKind.Utc)
                : null,
            instance.EscalationLevel,
            DateTime.SpecifyKind(instance.CreatedAt, DateTimeKind.Utc),
            instance.Reminder?.Title,
            instance.Reminder?.Description,
            instance.Reminder?.VoiceNoteUrl,
            instance.Reminder?.Priority
        );
    }

    /// <summary>
    /// Converts a local date to a UTC date range.
    /// For example, Feb 6 in IST (UTC+5:30) becomes:
    /// - Start: Feb 5, 18:30 UTC
    /// - End: Feb 6, 18:30 UTC
    /// </summary>
    private static (DateTime StartUtc, DateTime EndUtc) ConvertLocalDateRangeToUtc(DateTime localDate, string timezone)
    {
        try
        {
            var tz = DateTimeZoneProviders.Tzdb.GetZoneOrNull(timezone);
            if (tz == null)
            {
                // Fallback to treating as UTC
                return (localDate.Date, localDate.Date.AddDays(1));
            }

            // Start of day in local timezone
            var startLocal = new LocalDateTime(localDate.Year, localDate.Month, localDate.Day, 0, 0);
            var startZoned = startLocal.InZoneLeniently(tz);
            var startUtc = startZoned.ToDateTimeUtc();

            // End of day (start of next day) in local timezone
            var endLocal = new LocalDateTime(localDate.Year, localDate.Month, localDate.Day, 0, 0).PlusDays(1);
            var endZoned = endLocal.InZoneLeniently(tz);
            var endUtc = endZoned.ToDateTimeUtc();

            return (startUtc, endUtc);
        }
        catch
        {
            // Fallback to treating as UTC
            return (localDate.Date, localDate.Date.AddDays(1));
        }
    }
}
