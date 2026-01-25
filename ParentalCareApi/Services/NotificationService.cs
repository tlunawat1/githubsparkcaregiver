namespace ParentalCareApi.Services;

public class NotificationService : INotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly IConfiguration _configuration;

    public NotificationService(ILogger<NotificationService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    public async Task SendPushNotificationAsync(string deviceToken, string title, string body, Dictionary<string, string>? data = null)
    {
        // TODO: Implement Azure Notification Hubs integration
        // For MVP, we'll log the notification
        _logger.LogInformation(
            "Push notification - Token: {Token}, Title: {Title}, Body: {Body}",
            deviceToken[..Math.Min(10, deviceToken.Length)] + "...",
            title,
            body
        );

        await Task.CompletedTask;
    }

    public async Task SendPushNotificationsAsync(IEnumerable<string> deviceTokens, string title, string body, Dictionary<string, string>? data = null)
    {
        var tasks = deviceTokens.Select(token => SendPushNotificationAsync(token, title, body, data));
        await Task.WhenAll(tasks);
    }
}
