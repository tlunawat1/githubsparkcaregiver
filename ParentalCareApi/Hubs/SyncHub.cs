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

        if (userId != null)
        {
            // Add user to their personal group for targeted messages
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
            _logger.LogInformation("User connected: {UserId} ({UserName})", userId, userName);
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userId != null)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"user:{userId}");
            _logger.LogInformation("User disconnected: {UserId}", userId);
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
    public static async Task SendToUserAsync(
        this IHubContext<SyncHub> hubContext,
        string userId,
        string method,
        object? arg = null)
    {
        await hubContext.Clients.User(userId).SendAsync(method, arg);
    }

    // Send to all caregivers of a dependent
    public static async Task SendToCaregiversOfDependentAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        string method,
        object? arg = null)
    {
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync(method, arg);
    }

    // Send instance status changed event
    public static async Task SendInstanceStatusChangedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object instanceDto)
    {
        await hubContext.Clients.User(dependentId).SendAsync("InstanceStatusChanged", instanceDto);
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceStatusChanged", instanceDto);
    }

    // Send instance created event
    public static async Task SendInstanceCreatedAsync(
        this IHubContext<SyncHub> hubContext,
        string dependentId,
        object instanceDto)
    {
        await hubContext.Clients.User(dependentId).SendAsync("InstanceCreated", instanceDto);
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceCreated", instanceDto);
    }
}
