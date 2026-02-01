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
[Route("api/reminder-instances")]
[Authorize]
public class ReminderInstancesController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly INotificationJobService _notificationJobService;
    private readonly ILogger<ReminderInstancesController> _logger;

    public ReminderInstancesController(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationJobService notificationJobService,
        ILogger<ReminderInstancesController> logger)
    {
        _context = context;
        _hubContext = hubContext;
        _notificationJobService = notificationJobService;
        _logger = logger;
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

            query = query.Where(i => i.Reminder.DependentId == dependentId);
        }
        else if (userRole == "dependent")
        {
            // Dependents can only see their own instances
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

        // Filter by date (use UTC date range)
        if (date.HasValue)
        {
            // Convert to UTC if not already, and use the date part
            var dateUtc = date.Value.Kind == DateTimeKind.Utc
                ? date.Value.Date
                : DateTime.SpecifyKind(date.Value.Date, DateTimeKind.Utc);
            var startOfDay = dateUtc;
            var endOfDay = startOfDay.AddDays(1);

            _logger.LogInformation("Filtering instances for date range: {Start} to {End}", startOfDay, endOfDay);

            query = query.Where(i => i.ScheduledTime >= startOfDay && i.ScheduledTime < endOfDay);
        }

        // Only get instances for active reminders
        query = query.Where(i => i.Reminder.IsActive);

        var instances = await query
            .OrderBy(i => i.ScheduledTime)
            .Select(i => MapToDto(i))
            .ToListAsync();

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

        // Schedule notification jobs for this instance
        await _notificationJobService.ScheduleNotificationJobsAsync(instance.Id, request.ScheduledTime);

        // Load the reminder for the DTO
        await _context.Entry(instance).Reference(i => i.Reminder).LoadAsync();

        // Notify via SignalR
        await _hubContext.SendToUserAsync(reminder.DependentId, "InstanceCreated", MapToDto(instance));
        await _hubContext.SendToCaregiversOfDependentAsync(reminder.DependentId, "InstanceCreated", MapToDto(instance));

        _logger.LogInformation("Created instance {InstanceId} for reminder {ReminderId}", instance.Id, request.ReminderId);

        return CreatedAtAction(nameof(GetInstance), new { id = instance.Id }, MapToDto(instance));
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

        // Cancel any pending notification jobs
        await _notificationJobService.CancelNotificationJobsAsync(id);

        await _context.SaveChangesAsync();

        // Notify via SignalR
        var dto = MapToDto(instance);
        await _hubContext.SendToUserAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);
        await _hubContext.SendToCaregiversOfDependentAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);

        _logger.LogInformation("Instance {InstanceId} marked as completed, notification jobs cancelled", id);

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

        instance.Status = "snoozed";
        instance.SnoozedUntil = request.SnoozedUntil;
        await _context.SaveChangesAsync();

        // Notify via SignalR
        var dto = MapToDto(instance);
        await _hubContext.SendToUserAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);
        await _hubContext.SendToCaregiversOfDependentAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);

        _logger.LogInformation("Instance {InstanceId} snoozed until {SnoozedUntil}", id, request.SnoozedUntil);

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

        // Cancel any pending notification jobs
        await _notificationJobService.CancelNotificationJobsAsync(id);

        await _context.SaveChangesAsync();

        // Notify via SignalR
        var dto = MapToDto(instance);
        await _hubContext.SendToUserAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);
        await _hubContext.SendToCaregiversOfDependentAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);

        _logger.LogInformation("Instance {InstanceId} marked as missed, notification jobs cancelled", id);

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

        // Notify via SignalR
        var dto = MapToDto(instance);
        await _hubContext.SendToUserAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);
        await _hubContext.SendToCaregiversOfDependentAsync(instance.Reminder.DependentId, "InstanceStatusChanged", dto);

        _logger.LogInformation("Instance {InstanceId} escalated to level {Level}", id, instance.EscalationLevel);

        return Ok(dto);
    }

    private static ReminderInstanceDto MapToDto(ReminderInstance instance)
    {
        return new ReminderInstanceDto(
            instance.Id,
            instance.ReminderId,
            instance.ScheduledTime,
            instance.Status,
            instance.CompletedAt,
            instance.SnoozedUntil,
            instance.EscalationLevel,
            instance.CreatedAt,
            instance.Reminder?.Title,
            instance.Reminder?.Description,
            instance.Reminder?.VoiceNoteUrl,
            instance.Reminder?.Priority
        );
    }
}
