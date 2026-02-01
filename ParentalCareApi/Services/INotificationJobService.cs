namespace ParentalCareApi.Services;

public interface INotificationJobService
{
    Task SendReminderNotificationAsync(string instanceId, int escalationLevel = 0);
    Task SendEscalatedNotificationAsync(string instanceId, int escalationLevel);
    Task MarkAsMissedAsync(string instanceId);
    Task ScheduleNotificationJobsAsync(string instanceId, DateTime scheduledTimeUtc);
    Task CancelNotificationJobsAsync(string instanceId);
}
