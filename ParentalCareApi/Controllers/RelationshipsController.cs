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
public class RelationshipsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly IAuthService _authService;
    private readonly INotificationService _notificationService;
    private readonly ILogger<RelationshipsController> _logger;

    public RelationshipsController(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        IAuthService authService,
        INotificationService notificationService,
        ILogger<RelationshipsController> logger)
    {
        _context = context;
        _hubContext = hubContext;
        _authService = authService;
        _notificationService = notificationService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<List<RelationshipDto>>> GetRelationships()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        List<CareRelationship> relationships;

        if (userRole == "caregiver")
        {
            relationships = await _context.CareRelationships
                .Include(r => r.Dependent)
                .Where(r => r.CaregiverId == userId && r.Status != "removed")
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();
        }
        else
        {
            relationships = await _context.CareRelationships
                .Include(r => r.Caregiver)
                .Where(r => r.DependentId == userId && r.Status != "removed")
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();
        }

        return Ok(relationships.Select(r => MapToDto(r, userRole == "caregiver")).ToList());
    }

    [HttpGet("pending")]
    public async Task<ActionResult<List<PendingLinkDto>>> GetPendingLinks()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        if (userRole == "dependent")
        {
            var pendingLinks = await _context.CareRelationships
                .Include(r => r.Caregiver)
                .Where(r => r.DependentId == userId && r.Status == "pending")
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return Ok(pendingLinks.Select(r => new PendingLinkDto(
                r.Id,
                r.CaregiverId,
                r.Caregiver.Name,
                r.Caregiver.AvatarUrl,
                r.Status,
                r.CreatedAt
            )).ToList());
        }
        else
        {
            var pendingLinks = await _context.CareRelationships
                .Include(r => r.Dependent)
                .Where(r => r.CaregiverId == userId && r.Status == "pending")
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return Ok(pendingLinks.Select(r => new PendingLinkDto(
                r.Id,
                r.DependentId,
                r.Dependent.Name,
                r.Dependent.AvatarUrl,
                r.Status,
                r.CreatedAt
            )).ToList());
        }
    }

    [HttpPost]
    public async Task<ActionResult<CreateRelationshipResponse>> CreateRelationship(
        [FromBody] CreateRelationshipRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

        if (userId == null)
            return Unauthorized();

        // Find target user by unique code or email
        User? targetUser = null;

        if (request.TargetUserIdentifier.Contains('@'))
        {
            targetUser = await _context.Users.FirstOrDefaultAsync(
                u => u.Email == request.TargetUserIdentifier.ToLowerInvariant());
        }
        else
        {
            targetUser = await _context.Users.FirstOrDefaultAsync(
                u => u.UniqueCode == request.TargetUserIdentifier.ToUpperInvariant());
        }

        if (targetUser == null)
            return NotFound(new { message = "User not found with provided code or email" });

        // Determine caregiver and dependent based on roles
        string caregiverId, dependentId;

        if (userRole == "caregiver" && targetUser.Role == "dependent")
        {
            caregiverId = userId;
            dependentId = targetUser.Id;
        }
        else if (userRole == "dependent" && targetUser.Role == "caregiver")
        {
            caregiverId = targetUser.Id;
            dependentId = userId;
        }
        else
        {
            return BadRequest(new { message = "Invalid role combination. A caregiver must link with a dependent." });
        }

        // Check if relationship already exists
        var existingRelationship = await _context.CareRelationships.FirstOrDefaultAsync(
            r => r.CaregiverId == caregiverId &&
                 r.DependentId == dependentId &&
                 r.Status != "removed");

        if (existingRelationship != null)
        {
            if (existingRelationship.Status == "active")
                return Conflict(new { message = "Relationship already exists and is active" });

            return Conflict(new { message = "A pending relationship already exists", relationshipId = existingRelationship.Id });
        }

        var linkingCode = _authService.GenerateLinkingCode();

        var relationship = new CareRelationship
        {
            Id = Guid.NewGuid().ToString(),
            CaregiverId = caregiverId,
            DependentId = dependentId,
            Status = "pending",
            LinkingCode = linkingCode,
            CodeExpiresAt = DateTime.UtcNow.AddHours(1),
            InitiatedBy = request.InitiatedBy,
            CreatedAt = DateTime.UtcNow
        };

        _context.CareRelationships.Add(relationship);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Relationship created: {Id}, Caregiver: {CaregiverId}, Dependent: {DependentId}",
            relationship.Id, caregiverId, dependentId);

        // Notify the other party via SignalR
        var notifyUserId = userRole == "caregiver" ? dependentId : caregiverId;
        await _hubContext.Clients.User(notifyUserId).SendAsync("LinkRequestReceived", new
        {
            relationshipId = relationship.Id,
            initiatedBy = request.InitiatedBy,
            caregiverId,
            dependentId
        });

        // Send push notification if device token exists
        var notifyUser = await _context.Users.FindAsync(notifyUserId);
        if (!string.IsNullOrEmpty(notifyUser?.DeviceToken))
        {
            var currentUser = await _context.Users.FindAsync(userId);
            await _notificationService.SendPushNotificationAsync(
                notifyUser.DeviceToken,
                "New Link Request",
                $"{currentUser?.Name ?? "Someone"} wants to connect with you",
                new Dictionary<string, string>
                {
                    { "type", "link_request" },
                    { "relationshipId", relationship.Id }
                }
            );
        }

        return CreatedAtAction(nameof(CreateRelationship), new CreateRelationshipResponse(
            relationship.Id,
            relationship.Status,
            relationship.LinkingCode,
            relationship.CodeExpiresAt,
            "Relationship created. Share the linking code with the other party."
        ));
    }

    [HttpPost("{id}/verify")]
    public async Task<ActionResult<VerifyLinkingCodeResponse>> VerifyLinkingCode(
        string id,
        [FromBody] VerifyLinkingCodeRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var relationship = await _context.CareRelationships
            .Include(r => r.Caregiver)
            .Include(r => r.Dependent)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (relationship == null)
            return NotFound(new { message = "Relationship not found" });

        if (relationship.Status != "pending")
            return BadRequest(new VerifyLinkingCodeResponse(false, "Relationship is not pending", null));

        // Verify user is part of this relationship
        if (relationship.CaregiverId != userId && relationship.DependentId != userId)
            return Forbid();

        // Check verification attempts
        if (relationship.VerificationAttempts >= 5)
            return BadRequest(new VerifyLinkingCodeResponse(false, "Too many verification attempts", null));

        // MVP: Accept hardcoded code "12345" or actual linking code
        var isValidCode = request.Code == "12345" ||
            (relationship.LinkingCode == request.Code && relationship.CodeExpiresAt > DateTime.UtcNow);

        if (!isValidCode)
        {
            relationship.VerificationAttempts++;
            await _context.SaveChangesAsync();

            return BadRequest(new VerifyLinkingCodeResponse(false, "Invalid or expired linking code", null));
        }

        relationship.Status = "active";
        relationship.LinkingCode = null;
        relationship.CodeExpiresAt = null;
        relationship.VerifiedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Relationship verified: {Id}", relationship.Id);

        // Notify both parties via SignalR
        await _hubContext.Clients.User(relationship.CaregiverId).SendAsync("LinkVerified", new
        {
            relationshipId = relationship.Id,
            dependentId = relationship.DependentId,
            dependentName = relationship.Dependent.Name
        });

        await _hubContext.Clients.User(relationship.DependentId).SendAsync("LinkVerified", new
        {
            relationshipId = relationship.Id,
            caregiverId = relationship.CaregiverId,
            caregiverName = relationship.Caregiver.Name
        });

        // Send push notifications
        var otherUserId = userId == relationship.CaregiverId ? relationship.DependentId : relationship.CaregiverId;
        var otherUser = await _context.Users.FindAsync(otherUserId);
        var currentUser = await _context.Users.FindAsync(userId);

        if (!string.IsNullOrEmpty(otherUser?.DeviceToken))
        {
            await _notificationService.SendPushNotificationAsync(
                otherUser.DeviceToken,
                "Link Verified",
                $"You are now connected with {currentUser?.Name ?? "a user"}",
                new Dictionary<string, string>
                {
                    { "type", "link_verified" },
                    { "relationshipId", relationship.Id }
                }
            );
        }

        var dto = MapToDto(relationship, relationship.CaregiverId == userId);

        return Ok(new VerifyLinkingCodeResponse(true, "Relationship verified successfully", dto));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRelationship(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var relationship = await _context.CareRelationships.FindAsync(id);

        if (relationship == null)
            return NotFound(new { message = "Relationship not found" });

        // Verify user is part of this relationship
        if (relationship.CaregiverId != userId && relationship.DependentId != userId)
            return Forbid();

        relationship.Status = "removed";

        await _context.SaveChangesAsync();

        _logger.LogInformation("Relationship removed: {Id}", id);

        // Notify the other party
        var notifyUserId = userId == relationship.CaregiverId ? relationship.DependentId : relationship.CaregiverId;
        await _hubContext.Clients.User(notifyUserId).SendAsync("LinkRemoved", new
        {
            relationshipId = relationship.Id
        });

        return Ok(new { message = "Relationship removed" });
    }

    [HttpGet("{id}/code")]
    public async Task<ActionResult> GetLinkingCode(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var relationship = await _context.CareRelationships.FindAsync(id);

        if (relationship == null)
            return NotFound(new { message = "Relationship not found" });

        // Verify user is part of this relationship
        if (relationship.CaregiverId != userId && relationship.DependentId != userId)
            return Forbid();

        if (relationship.Status != "pending")
            return BadRequest(new { message = "Relationship is not pending" });

        return Ok(new
        {
            linkingCode = relationship.LinkingCode,
            expiresAt = relationship.CodeExpiresAt
        });
    }

    [HttpPost("{id}/regenerate-code")]
    public async Task<ActionResult> RegenerateLinkingCode(string id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId == null)
            return Unauthorized();

        var relationship = await _context.CareRelationships.FindAsync(id);

        if (relationship == null)
            return NotFound(new { message = "Relationship not found" });

        // Verify user is part of this relationship
        if (relationship.CaregiverId != userId && relationship.DependentId != userId)
            return Forbid();

        if (relationship.Status != "pending")
            return BadRequest(new { message = "Relationship is not pending" });

        relationship.LinkingCode = _authService.GenerateLinkingCode();
        relationship.CodeExpiresAt = DateTime.UtcNow.AddHours(1);
        relationship.VerificationAttempts = 0;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            linkingCode = relationship.LinkingCode,
            expiresAt = relationship.CodeExpiresAt
        });
    }

    private static RelationshipDto MapToDto(CareRelationship r, bool includeDependent)
    {
        return new RelationshipDto(
            r.Id,
            r.CaregiverId,
            r.DependentId,
            r.Status,
            r.LinkingCode,
            r.CodeExpiresAt,
            r.InitiatedBy,
            r.CreatedAt,
            r.VerifiedAt,
            r.Caregiver != null ? new UserSearchResult(
                r.Caregiver.Id,
                r.Caregiver.Name,
                r.Caregiver.Role,
                r.Caregiver.UniqueCode,
                r.Caregiver.AvatarUrl
            ) : null,
            r.Dependent != null ? new UserSearchResult(
                r.Dependent.Id,
                r.Dependent.Name,
                r.Dependent.Role,
                r.Dependent.UniqueCode,
                r.Dependent.AvatarUrl
            ) : null
        );
    }
}
