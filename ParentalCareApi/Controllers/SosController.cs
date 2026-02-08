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
using ParentalCareApi.Utils;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SosController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly INotificationService _notificationService;
    private readonly ILogger<SosController> _logger;

    public SosController(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationService notificationService,
        ILogger<SosController> logger)
    {
        _context = context;
        _hubContext = hubContext;
        _notificationService = notificationService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<List<SosEventDto>>> GetSosEvents(
        [FromQuery] string? dependentId = null,
        [FromQuery] bool recentOnly = false)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        IQueryable<SosEvent> query = _context.SosEvents
            .Include(s => s.Dependent)
            .Include(s => s.Resolver);

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

                query = query.Where(s => s.DependentId == dependentId);
            }
            else
            {
                // Get SOS events for all dependents of this caregiver
                var dependentIds = await _context.CareRelationships
                    .Where(cr => cr.CaregiverId == userId && cr.Status == "active")
                    .Select(cr => cr.DependentId)
                    .ToListAsync();

                query = query.Where(s => dependentIds.Contains(s.DependentId));
            }
        }
        else
        {
            // Dependent sees their own SOS events
            query = query.Where(s => s.DependentId == userId);
        }

        if (recentOnly)
        {
            var cutoff = DateTime.UtcNow.AddHours(-24);
            query = query.Where(s => s.TriggeredAt >= cutoff);
        }

        var events = await query.OrderByDescending(s => s.TriggeredAt).ToListAsync();

        return Ok(events.Select(MapToDto).ToList());
    }

    [HttpGet("active")]
    public async Task<ActionResult<SosEventDto?>> GetActiveSosEvent([FromQuery] string? dependentId = null)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        string targetDependentId;

        if (userRole == "dependent")
        {
            targetDependentId = userId;
        }
        else if (!string.IsNullOrEmpty(dependentId))
        {
            // Verify caregiver has relationship
            var hasRelationship = await _context.CareRelationships.AnyAsync(
                cr => cr.CaregiverId == userId &&
                      cr.DependentId == dependentId &&
                      cr.Status == "active");

            if (!hasRelationship)
                return Forbid();

            targetDependentId = dependentId;
        }
        else
        {
            return BadRequest(new { message = "dependentId is required for caregivers" });
        }

        var activeEvent = await _context.SosEvents
            .Include(s => s.Dependent)
            .Include(s => s.Resolver)
            .Where(s => s.DependentId == targetDependentId && s.Status == "triggered")
            .OrderByDescending(s => s.TriggeredAt)
            .FirstOrDefaultAsync();

        if (activeEvent == null)
            return Ok(null);

        return Ok(MapToDto(activeEvent));
    }

    [HttpPost]
    public async Task<ActionResult<TriggerSosResponse>> TriggerSos([FromBody] TriggerSosRequest? request = null)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        if (userRole != "dependent")
            return Forbid();

        // Check for existing active SOS
        var existingActive = await _context.SosEvents.AnyAsync(
            s => s.DependentId == userId && s.Status == "triggered");

        if (existingActive)
            return Conflict(new { message = "An active SOS event already exists" });

        var sosEvent = new SosEvent
        {
            Id = Guid.NewGuid().ToString(),
            DependentId = userId,
            Status = "triggered",
            TriggeredAt = DateTime.UtcNow,
            Notes = request?.Notes,
            CreatedAt = DateTime.UtcNow
        };

        _context.SosEvents.Add(sosEvent);
        await _context.SaveChangesAsync();

        _logger.LogWarning("SOS triggered by dependent {DependentId}", userId);

        // Get all caregivers for this dependent
        var caregiverRelationships = await _context.CareRelationships
            .Include(cr => cr.Caregiver)
            .Where(cr => cr.DependentId == userId && cr.Status == "active")
            .ToListAsync();

        var dependent = await _context.Users.FindAsync(userId);
        var notifiedCount = 0;

        var dependentName = NameFormatter.GetDisplayName(dependent);
        var dependentDisplay = string.IsNullOrWhiteSpace(dependentName)
            ? "A dependent"
            : dependentName;

        // Notify all caregivers (using user groups for reliable delivery)
        foreach (var relationship in caregiverRelationships)
        {
            // SignalR notification via user group
            await _hubContext.Clients.Group($"user:{relationship.CaregiverId}").SendAsync("SosTriggered", new
            {
                sosEventId = sosEvent.Id,
                dependentId = userId,
                dependentName = dependentDisplay,
                triggeredAt = sosEvent.TriggeredAt
            });

            // Push notification
            if (!string.IsNullOrEmpty(relationship.Caregiver?.DeviceToken))
            {
                await _notificationService.SendPushNotificationAsync(
                    relationship.Caregiver.DeviceToken,
                    "SOS Alert!",
                    $"{dependentDisplay} needs help!",
                    new Dictionary<string, string>
                    {
                        { "type", "sos_triggered" },
                        { "sosEventId", sosEvent.Id },
                        { "dependentId", userId }
                    }
                );
                notifiedCount++;
            }
        }

        return Ok(new TriggerSosResponse(
            sosEvent.Id,
            sosEvent.Status,
            sosEvent.TriggeredAt,
            "SOS alert triggered",
            notifiedCount
        ));
    }

    [HttpPut("{id}/resolve")]
    public async Task<ActionResult<ResolveSosResponse>> ResolveSos(string id, [FromBody] ResolveSosRequest? request = null)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        var sosEvent = await _context.SosEvents
            .Include(s => s.Dependent)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (sosEvent == null)
            return NotFound(new { message = "SOS event not found" });

        if (sosEvent.Status != "triggered")
            return BadRequest(new ResolveSosResponse(false, "SOS event is not active", null));

        // Verify access
        if (userRole == "dependent")
        {
            if (sosEvent.DependentId != userId)
                return Forbid();
        }
        else
        {
            var hasRelationship = await _context.CareRelationships.AnyAsync(
                cr => cr.CaregiverId == userId &&
                      cr.DependentId == sosEvent.DependentId &&
                      cr.Status == "active");

            if (!hasRelationship)
                return Forbid();
        }

        sosEvent.Status = "resolved";
        sosEvent.ResolvedAt = DateTime.UtcNow;
        sosEvent.ResolvedBy = userId;
        sosEvent.Notes = request?.Notes ?? sosEvent.Notes;

        await _context.SaveChangesAsync();

        // Reload with resolver
        sosEvent = await _context.SosEvents
            .Include(s => s.Dependent)
            .Include(s => s.Resolver)
            .FirstOrDefaultAsync(s => s.Id == id);

        _logger.LogInformation("SOS resolved: {Id} by {UserId}", id, userId);

        // Notify relevant parties
        var caregiverRelationships = await _context.CareRelationships
            .Where(cr => cr.DependentId == sosEvent!.DependentId && cr.Status == "active")
            .ToListAsync();

        // Notify caregivers (using user groups for reliable delivery)
        foreach (var relationship in caregiverRelationships)
        {
            await _hubContext.Clients.Group($"user:{relationship.CaregiverId}").SendAsync("SosResolved", new
            {
                sosEventId = sosEvent!.Id,
                resolvedBy = userId,
                resolvedAt = sosEvent.ResolvedAt
            });
        }

        // Notify dependent (using user group for reliable delivery)
        await _hubContext.Clients.Group($"user:{sosEvent!.DependentId}").SendAsync("SosResolved", new
        {
            sosEventId = sosEvent.Id,
            resolvedBy = userId,
            resolvedAt = sosEvent.ResolvedAt
        });

        return Ok(new ResolveSosResponse(true, "SOS event resolved", MapToDto(sosEvent)));
    }

    [HttpPut("{id}/cancel")]
    public async Task<IActionResult> CancelSos(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var sosEvent = await _context.SosEvents.FindAsync(id);

        if (sosEvent == null)
            return NotFound(new { message = "SOS event not found" });

        // Only dependent can cancel their own SOS
        if (sosEvent.DependentId != userId)
            return Forbid();

        if (sosEvent.Status != "triggered")
            return BadRequest(new { message = "SOS event is not active" });

        sosEvent.Status = "cancelled";
        sosEvent.ResolvedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("SOS cancelled: {Id}", id);

        // Notify caregivers
        var caregiverRelationships = await _context.CareRelationships
            .Where(cr => cr.DependentId == userId && cr.Status == "active")
            .ToListAsync();

        // Notify caregivers via user groups for reliable delivery
        foreach (var relationship in caregiverRelationships)
        {
            await _hubContext.Clients.Group($"user:{relationship.CaregiverId}").SendAsync("SosCancelled", new
            {
                sosEventId = sosEvent.Id
            });
        }

        return Ok(new { message = "SOS event cancelled" });
    }

    private static SosEventDto MapToDto(SosEvent s)
    {
        return new SosEventDto(
            s.Id,
            s.DependentId,
            s.Status,
            s.TriggeredAt,
            s.ResolvedAt,
            s.ResolvedBy,
            s.Notes,
            s.CreatedAt,
            NameFormatter.GetDisplayName(s.Dependent),
            NameFormatter.GetDisplayName(s.Resolver)
        );
    }
}
