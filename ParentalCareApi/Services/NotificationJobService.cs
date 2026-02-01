using System.Text.Json;
using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NodaTime;
using ParentalCareApi.Data;
using ParentalCareApi.Hubs;
using ParentalCareApi.Models;

namespace ParentalCareApi.Services;

public class NotificationJobService : INotificationJobService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<NotificationJobService> _logger;
    private readonly IConfiguration _configuration;

    public NotificationJobService(
        IServiceScopeFactory scopeFactory,
        ILogger<NotificationJobService> logger,
        IConfiguration configuration)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _configuration = configuration;
    }

    public async Task SendReminderNotificationAsync(string instanceId, int escalationLevel = 0)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var instance = await context.ReminderInstances
            .Include(i => i.Reminder)
            .ThenInclude(r => r.Dependent)
            .FirstOrDefaultAsync(i => i.Id == instanceId);

        if (instance == null)
        {
            _logger.LogWarning("Reminder instance {InstanceId} not found", instanceId);
            return;
        }

        // Skip if already completed or missed
        if (instance.Status == "completed" || instance.Status == "missed")
        {
            _logger.LogInformation("Skipping notification for {InstanceId} - status is {Status}", instanceId, instance.Status);
            return;
        }

        var reminder = instance.Reminder;
        var dependent = reminder.Dependent;

        // Build notification
        var title = GetNotificationTitle(reminder.Title, escalationLevel);
        var body = GetNotificationBody(reminder.Description, escalationLevel);
        var data = new Dictionary<string, string>
        {
            { "type", "reminder" },
            { "instanceId", instanceId },
            { "reminderId", reminder.Id },
            { "priority", reminder.Priority },
            { "escalationLevel", escalationLevel.ToString() },
            { "click_action", "OPEN_REMINDER" }
        };

        // Send notification
        var result = await notificationService.SendToUserAsync(dependent.Id, title, body, data);

        // Log notification
        await LogNotificationAsync(context, dependent.Id, "reminder", instanceId, title, body, data, escalationLevel, result);

        // Update escalation level
        if (escalationLevel > instance.EscalationLevel)
        {
            instance.EscalationLevel = escalationLevel;
            await context.SaveChangesAsync();

            // Notify via SignalR
            var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<SyncHub>>();
            await hubContext.Clients.Group($"user:{dependent.Id}").SendAsync("InstanceStatusChanged", new
            {
                instanceId = instance.Id,
                status = instance.Status,
                escalationLevel = instance.EscalationLevel
            });
        }

        _logger.LogInformation(
            "Sent reminder notification for instance {InstanceId}, escalation level {Level}",
            instanceId, escalationLevel);
    }

    public async Task SendEscalatedNotificationAsync(string instanceId, int escalationLevel)
    {
        await SendReminderNotificationAsync(instanceId, escalationLevel);
    }

    public async Task MarkAsMissedAsync(string instanceId)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var instance = await context.ReminderInstances
            .Include(i => i.Reminder)
            .FirstOrDefaultAsync(i => i.Id == instanceId);

        if (instance == null)
        {
            _logger.LogWarning("Reminder instance {InstanceId} not found for auto-miss", instanceId);
            return;
        }

        // Skip if already completed
        if (instance.Status == "completed")
        {
            _logger.LogInformation("Skipping auto-miss for {InstanceId} - already completed", instanceId);
            return;
        }

        // Skip if already missed
        if (instance.Status == "missed")
        {
            return;
        }

        instance.Status = "missed";
        await context.SaveChangesAsync();

        // Notify via SignalR
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<SyncHub>>();
        await hubContext.Clients.Group($"user:{instance.Reminder.DependentId}").SendAsync("InstanceStatusChanged", new
        {
            instanceId = instance.Id,
            status = instance.Status,
            escalationLevel = instance.EscalationLevel
        });

        // Also notify caregivers
        await hubContext.Clients.Group($"dependent:{instance.Reminder.DependentId}").SendAsync("InstanceStatusChanged", new
        {
            instanceId = instance.Id,
            status = instance.Status,
            escalationLevel = instance.EscalationLevel
        });

        _logger.LogInformation("Auto-marked instance {InstanceId} as missed", instanceId);
    }

    public async Task ScheduleNotificationJobsAsync(string instanceId, DateTime scheduledTimeUtc)
    {
        var escalationDelay = _configuration.GetValue<int>("Notifications:EscalationDelayMinutes", 5);
        var autoMissDelay = _configuration.GetValue<int>("Notifications:AutoMissDelayMinutes", 30);

        var jobIds = new List<string>();

        // Only schedule if the time is in the future
        if (scheduledTimeUtc > DateTime.UtcNow)
        {
            // Initial notification at scheduled time
            var job1 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.SendReminderNotificationAsync(instanceId, 0),
                scheduledTimeUtc
            );
            jobIds.Add(job1);

            // Escalation 1: +5 minutes
            var job2 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.SendEscalatedNotificationAsync(instanceId, 1),
                scheduledTimeUtc.AddMinutes(escalationDelay)
            );
            jobIds.Add(job2);

            // Escalation 2: +10 minutes
            var job3 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.SendEscalatedNotificationAsync(instanceId, 2),
                scheduledTimeUtc.AddMinutes(escalationDelay * 2)
            );
            jobIds.Add(job3);

            // Auto-miss: +30 minutes
            var job4 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.MarkAsMissedAsync(instanceId),
                scheduledTimeUtc.AddMinutes(autoMissDelay)
            );
            jobIds.Add(job4);

            _logger.LogInformation(
                "Scheduled {Count} notification jobs for instance {InstanceId} at {Time}",
                jobIds.Count, instanceId, scheduledTimeUtc);
        }
        else
        {
            _logger.LogInformation(
                "Skipping job scheduling for instance {InstanceId} - scheduled time {Time} is in the past",
                instanceId, scheduledTimeUtc);
        }

        // Store job IDs in the instance
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var instance = await context.ReminderInstances.FindAsync(instanceId);
        if (instance != null)
        {
            instance.NotificationJobIds = JsonSerializer.Serialize(jobIds);
            await context.SaveChangesAsync();
        }
    }

    public async Task CancelNotificationJobsAsync(string instanceId)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var instance = await context.ReminderInstances.FindAsync(instanceId);
        if (instance?.NotificationJobIds == null)
        {
            return;
        }

        try
        {
            var jobIds = JsonSerializer.Deserialize<List<string>>(instance.NotificationJobIds);
            if (jobIds != null)
            {
                foreach (var jobId in jobIds)
                {
                    BackgroundJob.Delete(jobId);
                }
                _logger.LogInformation("Cancelled {Count} notification jobs for instance {InstanceId}", jobIds.Count, instanceId);
            }

            // Clear job IDs
            instance.NotificationJobIds = null;
            await context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cancelling notification jobs for instance {InstanceId}", instanceId);
        }
    }

    private string GetNotificationTitle(string reminderTitle, int escalationLevel)
    {
        return escalationLevel switch
        {
            0 => $"Reminder: {reminderTitle}",
            1 => $"⚠️ Reminder: {reminderTitle}",
            2 => $"🔴 Urgent: {reminderTitle}",
            _ => $"Reminder: {reminderTitle}"
        };
    }

    private string GetNotificationBody(string? description, int escalationLevel)
    {
        var baseMessage = string.IsNullOrEmpty(description)
            ? "It's time for your reminder"
            : description;

        return escalationLevel switch
        {
            0 => baseMessage,
            1 => $"{baseMessage} (reminder)",
            2 => $"{baseMessage} (please respond)",
            _ => baseMessage
        };
    }

    private async Task LogNotificationAsync(
        AppDbContext context,
        string userId,
        string type,
        string referenceId,
        string title,
        string body,
        Dictionary<string, string> data,
        int escalationLevel,
        NotificationResult result)
    {
        var log = new NotificationLog
        {
            UserId = userId,
            Type = type,
            ReferenceId = referenceId,
            Title = title,
            Body = body,
            Payload = JsonSerializer.Serialize(data),
            EscalationLevel = escalationLevel,
            ScheduledAt = DateTime.UtcNow,
            SentAt = DateTime.UtcNow,
            Status = result.Success ? "sent" : "failed",
            ErrorMessage = result.Error,
            FcmMessageId = result.MessageId
        };

        context.NotificationLogs.Add(log);
        await context.SaveChangesAsync();
    }

    // Helper method to convert local time to UTC using user's timezone
    public static DateTime ConvertToUtc(int hour, int minute, DateTime date, string timezone)
    {
        try
        {
            var tz = DateTimeZoneProviders.Tzdb.GetZoneOrNull(timezone);
            if (tz == null)
            {
                // Fallback to UTC if timezone is invalid
                return new DateTime(date.Year, date.Month, date.Day, hour, minute, 0, DateTimeKind.Utc);
            }

            var localDateTime = new LocalDateTime(date.Year, date.Month, date.Day, hour, minute);

            // Handle DST transitions by using lenient mapping
            var zonedDateTime = localDateTime.InZoneLeniently(tz);

            return zonedDateTime.ToDateTimeUtc();
        }
        catch (Exception)
        {
            // Fallback to treating the time as UTC
            return new DateTime(date.Year, date.Month, date.Day, hour, minute, 0, DateTimeKind.Utc);
        }
    }
}
