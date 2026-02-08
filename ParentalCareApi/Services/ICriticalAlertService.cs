namespace ParentalCareApi.Services;

public interface ICriticalAlertService
{
    Task TriggerSosAlertAsync(
        string dependentId,
        string? dependentName,
        string sosEventId,
        IEnumerable<string> caregiverIds);

    Task TriggerUrgentReminderAsync(
        string dependentId,
        string? dependentName,
        string reminderInstanceId,
        IEnumerable<string> caregiverIds);

    Task AcknowledgeAlertAsync(string alertId, string status, string acknowledgedBy);
}
