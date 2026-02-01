namespace ParentalCareApi.Services;

public interface INotificationService
{
    Task SendPushNotificationAsync(string deviceToken, string title, string body, Dictionary<string, string>? data = null);
    Task SendPushNotificationsAsync(IEnumerable<string> deviceTokens, string title, string body, Dictionary<string, string>? data = null);
    Task<NotificationResult> SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null);
}

public class NotificationResult
{
    public bool Success { get; set; }
    public string? MessageId { get; set; }
    public string? Error { get; set; }
    public int SuccessCount { get; set; }
    public int FailureCount { get; set; }
    public List<string> FailedTokens { get; set; } = new();

    public static NotificationResult Succeeded(string? messageId = null) =>
        new() { Success = true, MessageId = messageId, SuccessCount = 1 };

    public static NotificationResult Failed(string error) =>
        new() { Success = false, Error = error, FailureCount = 1 };
}
