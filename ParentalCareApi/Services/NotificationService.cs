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
            data ??= new Dictionary<string, string>();

            var type = data.TryGetValue("type", out var t) ? t : null;
            var escalationLevel = 0;
            if (data.TryGetValue("escalationLevel", out var levelString))
            {
                _ = int.TryParse(levelString, out escalationLevel);
            }

            var isReminder = string.Equals(type, "reminder", StringComparison.OrdinalIgnoreCase);
            var isSos = string.Equals(type, "sos", StringComparison.OrdinalIgnoreCase);

            // For reminders, ensure each escalation shows as its own notification on Android.
            // Without an explicit collapse key/tag, Android/FCM may replace/collapse notifications,
            // which can look like the 2nd (+5min) escalation never arrived.
            data.TryGetValue("instanceId", out var instanceId);
            var androidCollapseKey = isReminder && !string.IsNullOrWhiteSpace(instanceId)
                ? $"reminder:{instanceId}:{escalationLevel}"
                : null;

            var channelId = GetAndroidChannelId(isReminder, isSos, escalationLevel);
            var isUrgentEscalation = isReminder && escalationLevel >= 2;

            // For urgent (3rd) escalation on Android we intentionally send a DATA-ONLY message
            // so the Flutter background handler can show an "insistent" local notification.
            if (isUrgentEscalation)
            {
                data["title"] = title;
                data["body"] = body;
            }

            var message = new Message
            {
                Token = deviceToken,
                Data = data,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    CollapseKey = androidCollapseKey,
                    Notification = isUrgentEscalation
                        ? null
                        : new AndroidNotification
                        {
                            ChannelId = channelId,
                            Tag = androidCollapseKey,
                            DefaultVibrateTimings = true
                        }
                },
                Apns = new ApnsConfig
                {
                    Headers = new Dictionary<string, string>
                    {
                        { "apns-priority", "10" }
                    },
                    Aps = new Aps
                    {
                        // For iOS: play default sound for level 0/1, custom for urgent escalation.
                        Sound = isReminder
                            ? (isUrgentEscalation ? "reminder_alarm.caf" : "default")
                            : null,
                        Badge = 1,
                        ContentAvailable = true
                    }
                }
            };

            if (!isUrgentEscalation)
            {
                message.Notification = new Notification
                {
                    Title = title,
                    Body = body
                };
            }
            else
            {
                // Provide an iOS alert when using Android data-only for urgent escalation.
                message.Apns.Aps.Alert = new ApsAlert
                {
                    Title = title,
                    Body = body
                };
            }

            // Android sound: leave null for default sound on channels; custom only for urgent.
            if (!isUrgentEscalation && isReminder)
            {
                // No explicit sound => use the channel's default sound.
                message.Android.Notification!.Sound = null;
            }
            if (!isUrgentEscalation && isSos)
            {
                message.Android.Notification!.Sound = null;
            }

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

    private static string GetAndroidChannelId(bool isReminder, bool isSos, int escalationLevel)
    {
        if (isSos)
        {
            return "sos_emergency";
        }

        if (isReminder)
        {
            if (escalationLevel >= 2) return "reminders_urgent";
            if (escalationLevel >= 1) return "reminders_high";
            return "reminders";
        }

        // Fallback for unknown types.
        return "reminders";
    }
}
