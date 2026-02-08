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
            var message = new Message
            {
                Token = deviceToken,
                Notification = new Notification
                {
                    Title = title,
                    Body = body
                },
                Data = data,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = "reminders",
                        Sound = "default",
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
                        Sound = "default",
                        Badge = 1,
                        ContentAvailable = true
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
            .Where(t => t.UserId == userId && t.IsValid && t.TokenType == "fcm")
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
