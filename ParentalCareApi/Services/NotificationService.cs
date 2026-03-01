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
            var message = BuildFcmMessage(deviceToken, title, body, data);
            var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation("FCM message sent successfully: {MessageId}", response);
        }
        catch (FirebaseMessagingException ex)
        {
            _logger.LogError(ex, "FCM send failed for token {Token}", deviceToken[..Math.Min(10, deviceToken.Length)] + "...");

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

    public async Task<List<NotificationResult>> SendBatchToUsersAsync(IList<BatchNotification> notifications)
    {
        if (notifications.Count == 0)
            return new List<NotificationResult>();

        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // Batch-resolve tokens: one query for all user IDs
        var userIds = notifications.Select(n => n.UserId).Distinct().ToList();
        var tokensByUser = await context.UserDeviceTokens
            .Where(t => userIds.Contains(t.UserId) && t.IsValid)
            .GroupBy(t => t.UserId)
            .ToDictionaryAsync(g => g.Key, g => g.Select(t => t.Token).ToList());

        // Fallback: check legacy DeviceToken for users with no valid tokens
        var usersWithoutTokens = userIds.Except(tokensByUser.Keys).ToList();
        if (usersWithoutTokens.Count > 0)
        {
            var legacyUsers = await context.Users
                .Where(u => usersWithoutTokens.Contains(u.Id) && u.DeviceToken != null)
                .Select(u => new { u.Id, u.DeviceToken })
                .ToListAsync();
            foreach (var u in legacyUsers)
            {
                if (!string.IsNullOrEmpty(u.DeviceToken))
                    tokensByUser[u.Id] = new List<string> { u.DeviceToken };
            }
        }

        var results = new List<NotificationResult>();

        if (!_firebaseInitialized)
        {
            foreach (var n in notifications)
            {
                _logger.LogInformation(
                    "Batch push notification (Firebase not configured) - UserId: {UserId}, Title: {Title}",
                    n.UserId, n.Title);
                results.Add(tokensByUser.ContainsKey(n.UserId)
                    ? NotificationResult.Succeeded()
                    : NotificationResult.Failed("No device tokens found"));
            }
            return results;
        }

        // Build all FCM messages
        var messageBatch = new List<(int NotificationIndex, Message Message, string Token)>();
        for (var i = 0; i < notifications.Count; i++)
        {
            var n = notifications[i];
            if (!tokensByUser.TryGetValue(n.UserId, out var tokens) || tokens.Count == 0)
            {
                results.Add(NotificationResult.Failed("No device tokens found"));
                continue;
            }

            results.Add(new NotificationResult()); // placeholder
            foreach (var token in tokens)
            {
                var msg = BuildFcmMessage(token, n.Title, n.Body, n.Data);
                messageBatch.Add((i, msg, token));
            }
        }

        // Send in chunks of 500
        var failedTokens = new List<string>();
        for (var offset = 0; offset < messageBatch.Count; offset += 500)
        {
            var chunk = messageBatch.Skip(offset).Take(500).ToList();
            var messages = chunk.Select(c => c.Message).ToList();

            try
            {
                var batchResponse = await FirebaseMessaging.DefaultInstance.SendEachAsync(messages);
                for (var j = 0; j < batchResponse.Responses.Count; j++)
                {
                    var resp = batchResponse.Responses[j];
                    var idx = chunk[j].NotificationIndex;

                    if (resp.IsSuccess)
                    {
                        results[idx].Success = true;
                        results[idx].SuccessCount++;
                        results[idx].MessageId ??= resp.MessageId;
                    }
                    else
                    {
                        results[idx].FailureCount++;
                        results[idx].FailedTokens.Add(chunk[j].Token);

                        if (resp.Exception is FirebaseMessagingException fme &&
                            (fme.MessagingErrorCode == MessagingErrorCode.Unregistered ||
                             fme.MessagingErrorCode == MessagingErrorCode.InvalidArgument))
                        {
                            failedTokens.Add(chunk[j].Token);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Batch FCM send failed for chunk starting at offset {Offset}", offset);
                foreach (var c in chunk)
                {
                    results[c.NotificationIndex].FailureCount++;
                    results[c.NotificationIndex].Error = ex.Message;
                }
            }
        }

        // Invalidate failed tokens
        foreach (var token in failedTokens)
        {
            await InvalidateTokenAsync(token);
        }

        _logger.LogInformation("Batch notification sent: {Total} notifications, {MessageCount} FCM messages",
            notifications.Count, messageBatch.Count);

        return results;
    }

    private Message BuildFcmMessage(string token, string title, string body, Dictionary<string, string>? data)
    {
        data ??= new Dictionary<string, string>();
        // Clone to avoid mutating the caller's dictionary
        data = new Dictionary<string, string>(data);

        var type = data.TryGetValue("type", out var t) ? t : null;
        var escalationLevel = 0;
        if (data.TryGetValue("escalationLevel", out var levelString))
        {
            _ = int.TryParse(levelString, out escalationLevel);
        }

        var isReminder = string.Equals(type, "reminder", StringComparison.OrdinalIgnoreCase);
        var isSos = string.Equals(type, "sos", StringComparison.OrdinalIgnoreCase);

        data.TryGetValue("instanceId", out var instanceId);
        var androidCollapseKey = isReminder && !string.IsNullOrWhiteSpace(instanceId)
            ? $"reminder:{instanceId}:{escalationLevel}"
            : null;

        var channelId = GetAndroidChannelId(isReminder, isSos, escalationLevel);
        var isUrgentEscalation = isReminder && escalationLevel >= 2;

        if (isUrgentEscalation)
        {
            data["title"] = title;
            data["body"] = body;
        }

        var message = new Message
        {
            Token = token,
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
            message.Apns.Aps.Alert = new ApsAlert
            {
                Title = title,
                Body = body
            };
        }

        if (!isUrgentEscalation && isReminder)
        {
            message.Android.Notification!.Sound = null;
        }
        if (!isUrgentEscalation && isSos)
        {
            message.Android.Notification!.Sound = null;
        }

        return message;
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
