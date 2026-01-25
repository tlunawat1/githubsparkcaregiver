namespace ParentalCareApi.Services;

public interface INotificationService
{
    Task SendPushNotificationAsync(string deviceToken, string title, string body, Dictionary<string, string>? data = null);
    Task SendPushNotificationsAsync(IEnumerable<string> deviceTokens, string title, string body, Dictionary<string, string>? data = null);
}
