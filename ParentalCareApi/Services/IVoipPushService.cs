namespace ParentalCareApi.Services;

public interface IVoipPushService
{
    Task SendVoipPushAsync(string deviceToken, Dictionary<string, object> payload);
}
