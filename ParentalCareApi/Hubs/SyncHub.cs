using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace ParentalCareApi.Hubs;

[Authorize]
public class SyncHub : Hub
{
    private readonly ILogger<SyncHub> _logger;

    public SyncHub(ILogger<SyncHub> logger)
    {
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userName = Context.User?.FindFirst(ClaimTypes.Name)?.Value;
        var userRole = Context.User?.FindFirst(ClaimTypes.Role)?.Value;

        if (userId != null)
        {
            // Add user to their personal group for targeted messages
            var groupName = $"user:{userId}";
            await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
            _logger.LogInformation("User connected: {UserId} ({UserName}), Role: {Role}, Added to group: {GroupName}, ConnectionId: {ConnectionId}",
                userId, userName, userRole, groupName, Context.ConnectionId);
        }
        else
        {
            _logger.LogWarning("User connected but no userId found in claims. ConnectionId: {ConnectionId}", Context.ConnectionId);
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId != null)
        {
            var groupName = $"user:{userId}";
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
            _logger.LogInformation("User disconnected: {UserId}, Removed from group: {GroupName}, ConnectionId: {ConnectionId}",
                userId, groupName, Context.ConnectionId);
        }

        await base.OnDisconnectedAsync(exception);
    }

    // Subscribe to updates for a specific dependent (for caregivers)
    public async Task SubscribeToDependent(string dependentId)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var userRole = Context.User?.FindFirst(ClaimTypes.Role)?.Value;

        if (userRole != "caregiver")
        {
            _logger.LogWarning("Non-caregiver attempted to subscribe to dependent: {UserId}", userId);
            return;
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, $"dependent:{dependentId}");
        _logger.LogInformation("Caregiver {CaregiverId} subscribed to dependent {DependentId}", userId, dependentId);
    }

    // Unsubscribe from dependent updates
    public async Task UnsubscribeFromDependent(string dependentId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"dependent:{dependentId}");

        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        _logger.LogInformation("Caregiver {CaregiverId} unsubscribed from dependent {DependentId}", userId, dependentId);
    }

    // Ping to keep connection alive
    public async Task Ping()
    {
        await Clients.Caller.SendAsync("Pong", DateTime.UtcNow);
    }

    // Notify that user is online (for presence)
    public async Task NotifyOnline()
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null) return;

        await Clients.Group($"user:{userId}").SendAsync("UserOnline", new
        {
            userId,
            timestamp = DateTime.UtcNow
        });
    }
}

// Extension methods for sending targeted messages from controllers
public static class SyncHubExtensions
{
    // Send to specific user by their user ID
    // Uses Clients.User() (framework-managed IUserIdProvider) for reliable delivery
    public static async Task SendToUserAsync(
        this IHubContext<SyncHub> hubContext,
        string userId,
        string method,
        object? arg = null)
    {
        await hubContext.Clients.User(userId).SendAsync(method, arg);
    }

    // Send to all caregivers of a dependent (via group - may be empty if caregivers disconnected)
    public static async Task SendToCaregiversOfDependentAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        string method,
        object? arg = null)
    {
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync(method, arg);
    }

    // Send instance status changed event to dependent and their caregivers
    // Uses Clients.User() for reliable delivery, with dependent group as fallback
    public static async Task SendInstanceStatusChangedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object instanceDto,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via framework-managed user mapping (robust across reconnections)
        await hubContext.Clients.User(dependentId).SendAsync("InstanceStatusChanged", instanceDto);

        // Send directly to each caregiver by user ID
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.User(caregiverId).SendAsync("InstanceStatusChanged", instanceDto);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceStatusChanged", instanceDto);
    }

    // Send instance created event to dependent and their caregivers
    // Uses Clients.User() for reliable delivery, with dependent group as fallback
    public static async Task SendInstanceCreatedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object instanceDto,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via framework-managed user mapping (robust across reconnections)
        await hubContext.Clients.User(dependentId).SendAsync("InstanceCreated", instanceDto);

        // Send directly to each caregiver by user ID
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.User(caregiverId).SendAsync("InstanceCreated", instanceDto);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceCreated", instanceDto);
    }

    // Send reminder created event to dependent and their caregivers
    // Uses Clients.User() for reliable delivery, with dependent group as fallback
    public static async Task SendReminderCreatedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object reminderDto,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via framework-managed user mapping
        await hubContext.Clients.User(dependentId).SendAsync("ReminderCreated", reminderDto);

        // Send directly to each caregiver by user ID
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.User(caregiverId).SendAsync("ReminderCreated", reminderDto);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("ReminderCreated", reminderDto);
    }

    // Send reminder updated event to dependent and their caregivers
    // Uses Clients.User() for reliable delivery, with dependent group as fallback
    public static async Task SendReminderUpdatedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object reminderDto,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via framework-managed user mapping
        await hubContext.Clients.User(dependentId).SendAsync("ReminderUpdated", reminderDto);

        // Send directly to each caregiver by user ID
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.User(caregiverId).SendAsync("ReminderUpdated", reminderDto);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("ReminderUpdated", reminderDto);
    }

    // Send reminder deleted event to dependent and their caregivers
    // Uses Clients.User() for reliable delivery, with dependent group as fallback
    public static async Task SendReminderDeletedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object data,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via framework-managed user mapping
        await hubContext.Clients.User(dependentId).SendAsync("ReminderDeleted", data);

        // Send directly to each caregiver by user ID
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.User(caregiverId).SendAsync("ReminderDeleted", data);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("ReminderDeleted", data);
    }
}
