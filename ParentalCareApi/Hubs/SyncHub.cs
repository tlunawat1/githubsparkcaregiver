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
    // Uses the user:{userId} group created on connect for reliable delivery
    public static async Task SendToUserAsync(
        this IHubContext<SyncHub> hubContext,
        string userId,
        string method,
        object? arg = null)
    {
        // Use group instead of Clients.User() for more reliable delivery
        // The user:{userId} group is created when user connects in OnConnectedAsync
        await hubContext.Clients.Group($"user:{userId}").SendAsync(method, arg);
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
    // Uses user:{userId} groups for reliable delivery
    public static async Task SendInstanceStatusChangedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object instanceDto,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via their user group (created on connect)
        await hubContext.Clients.Group($"user:{dependentId}").SendAsync("InstanceStatusChanged", instanceDto);

        // Send to each caregiver via their user group
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.Group($"user:{caregiverId}").SendAsync("InstanceStatusChanged", instanceDto);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceStatusChanged", instanceDto);
    }

    // Send instance created event to dependent and their caregivers
    // Uses user:{userId} groups for reliable delivery
    public static async Task SendInstanceCreatedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object instanceDto,
        IEnumerable<string>? caregiverIds = null)
    {
        // Send to dependent via their user group (created on connect)
        await hubContext.Clients.Group($"user:{dependentId}").SendAsync("InstanceCreated", instanceDto);

        // Send to each caregiver via their user group
        if (caregiverIds != null)
        {
            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.Group($"user:{caregiverId}").SendAsync("InstanceCreated", instanceDto);
            }
        }

        // Also send to dependent:{dependentId} group as fallback (for subscribed caregivers)
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceCreated", instanceDto);
    }
}
