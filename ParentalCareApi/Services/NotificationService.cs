using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.Models;

namespace ParentalCareApi.Services;

public class NotificationService : INotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly IConfiguration _configuration;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly bool _firebaseInitialized;

    public NotificationService(
        ILogger<NotificationService> logger,
        IConfiguration configuration,
        IServiceScopeFactory scopeFactory)
    {
        _logger = logger;
        _configuration = configuration;
        _scopeFactory = scopeFactory;
        _firebaseInitialized = FirebaseApp.DefaultInstance != null;
    }

    public async Task SendPushNotificationAsync(string deviceToken, string title, string body, Dictionary<string, string>? data = null)
    {
        if (string.IsNullOrEmpty(deviceToken))
        {
            _logger.LogWarning("Cannot send notification: device token is empty");
            return;
        }

        if (!_firebaseInitialized)
        {
            _logger.LogInformation(
                "Push notification (Firebase not configured) - Token: {Token}, Title: {Title}, Body: {Body}",
                deviceToken[..Math.Min(10, deviceToken.Length)] + "...",
                title,
                body
            );
            return;
        }

        try
        {
            // For interactive reminder notifications, we intentionally send data-only FCM messages.
            // Android-rendered (notification payload) messages cannot include our app-defined action
            // buttons (Done/Decline). Data-only ensures Flutter can always render a local
            // notification with actions in all app states.
            var isReminderInteractive = data != null &&
                (
                    (data.TryGetValue("type", out var type) && string.Equals(type, "reminder", StringComparison.OrdinalIgnoreCase)) ||
                    (data.TryGetValue("eventType", out var eventType) && eventType.Contains("reminder", StringComparison.OrdinalIgnoreCase)) ||
                    data.ContainsKey("instanceId")
                );

            var channelId = data != null && data.TryGetValue("androidChannelId", out var androidChannelId)
                ? androidChannelId
                : "reminders";

            var isCritical = data != null &&
                             data.TryGetValue("critical", out var criticalValue) &&
                             string.Equals(criticalValue, "true", StringComparison.OrdinalIgnoreCase);

            // Ensure title/body are always available to the client even when we send data-only.
            // (Client-side local notifications use these keys.)
            var effectiveData = data == null
                ? new Dictionary<string, string>()
                : new Dictionary<string, string>(data);

            effectiveData.TryAdd("title", title);
            effectiveData.TryAdd("body", body);
            effectiveData.TryAdd("androidChannelId", channelId);

            var message = new Message
            {
                Token = deviceToken,
                Notification = isReminderInteractive
                    ? null
                    : new Notification
                    {
                        Title = title,
                        Body = body
                    },
                Data = effectiveData,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    TimeToLive = TimeSpan.FromHours(_configuration.GetValue<int>("Notifications:DefaultTtlHours", 4)),
                    Notification = isReminderInteractive
                        ? null
                        : new AndroidNotification
                        {
                            ChannelId = channelId,
                            Sound = "default",
                            DefaultVibrateTimings = true,
                            Tag = effectiveData.TryGetValue("eventId", out var eventId) ? eventId : null
                        }
                },
                Apns = new ApnsConfig
                {
                    Headers = new Dictionary<string, string>
                    {
                        { "apns-priority", "10" },
                        // When sending data-only, iOS still needs a push type.
                        // We keep alert to preserve existing behavior on iOS, while Android remains interactive.
                        { "apns-push-type", "alert" }
                    },
                    Aps = new Aps
                    {
                        Sound = "default",
                        Badge = 1,
                        ContentAvailable = true,
                        MutableContent = isCritical
                    }
                }
            };

            var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation("FCM message sent successfully: {MessageId}", response);
        }
        catch (FirebaseMessagingException ex)
        {
            _logger.LogError(ex, "FCM send failed for token {Token}", deviceToken[..Math.Min(10, deviceToken.Length)] + "...");

            // Handle invalid token - mark as invalid in database
            if (ex.MessagingErrorCode == MessagingErrorCode.Unregistered ||
                ex.MessagingErrorCode == MessagingErrorCode.InvalidArgument)
            {
                await InvalidateTokenAsync(deviceToken);
            }
        }
    }

    public async Task SendPushNotificationsAsync(IEnumerable<string> deviceTokens, string title, string body, Dictionary<string, string>? data = null)
    {
        var tasks = deviceTokens
            .Where(t => !string.IsNullOrEmpty(t))
            .Select(token => SendPushNotificationAsync(token, title, body, data));
        await Task.WhenAll(tasks);
    }

    public async Task<NotificationResult> SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // Get all valid device tokens for the user
        var tokens = await context.UserDeviceTokens
            .Where(t => t.UserId == userId && t.IsValid)
            .Select(t => t.Token)
            .ToListAsync();

        if (!tokens.Any())
        {
            // Fallback to legacy single device token
            var user = await context.Users.FindAsync(userId);
            if (user?.DeviceToken != null)
            {
                tokens.Add(user.DeviceToken);
            }
        }

        if (!tokens.Any())
        {
            _logger.LogWarning("No device tokens found for user {UserId}", userId);
            return NotificationResult.Failed("No device tokens found");
        }

        var result = new NotificationResult();
        var failedTokens = new List<string>();

        foreach (var token in tokens)
        {
            try
            {
                await SendPushNotificationAsync(token, title, body, data);
                result.SuccessCount++;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send notification to token");
                result.FailureCount++;
                failedTokens.Add(token);
            }
        }

        result.Success = result.SuccessCount > 0;
        result.FailedTokens = failedTokens;
        return result;
    }

    private async Task InvalidateTokenAsync(string deviceToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var token = await context.UserDeviceTokens
                .FirstOrDefaultAsync(t => t.Token == deviceToken);

            if (token != null)
            {
                token.IsValid = false;
                token.UpdatedAt = DateTime.UtcNow;
                await context.SaveChangesAsync();
                _logger.LogInformation("Invalidated device token: {TokenId}", token.Id);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to invalidate device token");
        }
    }
}
