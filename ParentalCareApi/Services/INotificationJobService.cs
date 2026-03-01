namespace ParentalCareApi.Services;

public interface INotificationJobService
{
    Task ProcessDueNotificationsAsync();
    Task SendReminderNotificationAsync(string instanceId, int escalationLevel = 0);
    Task SendEscalatedNotificationAsync(string instanceId, int escalationLevel);
    Task MarkAsMissedAsync(string instanceId);
    Task ScheduleNotificationJobsAsync(string instanceId, DateTime scheduledTimeUtc);
    Task CancelNotificationJobsAsync(string instanceId);
    Task CancelReminderNotificationJobsAsync(string reminderId);

    /// <summary>
    /// Processes notification scheduling for all instances of a reminder.
    /// This is designed to be called from a background job, decoupled from the HTTP request.
    /// </summary>
    Task ProcessReminderNotificationsAsync(string reminderId);

    /// <summary>
    /// Reschedules notification jobs for all instances of a reminder.
    /// Cancels existing jobs and schedules new ones based on updated times.
    /// This is designed to be called from a background job.
    /// </summary>
    Task RescheduleReminderNotificationsAsync(string reminderId);
}
