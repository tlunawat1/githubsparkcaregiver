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

    public async Task ProcessDueNotificationsAsync()
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<SyncHub>>();

        var now = DateTime.UtcNow;
        var escalationDelay = _configuration.GetValue<int>("Notifications:EscalationDelayMinutes", 5);
        var autoMissDelay = _configuration.GetValue<int>("Notifications:AutoMissDelayMinutes", 30);

        // 6a: Query due instances (1 DB query)
        var dueInstances = await context.ReminderInstances
            .Include(i => i.Reminder).ThenInclude(r => r.Dependent)
            .Where(i => i.NextDueTime != null
                     && i.NextDueTime <= now
                     && (i.Status == "pending" || i.Status == "snoozed")
                     && i.Reminder.IsActive)
            .ToListAsync();

        if (dueInstances.Count == 0)
            return;

        _logger.LogInformation("Tick processor: found {Count} due instances", dueInstances.Count);

        // 6b: Batch-load caregiver relationships (1 DB query)
        var dependentIds = dueInstances.Select(i => i.Reminder.DependentId).Distinct().ToList();
        var caregiverMap = await context.CareRelationships
            .Where(cr => dependentIds.Contains(cr.DependentId) && cr.Status == "active")
            .GroupBy(cr => cr.DependentId)
            .ToDictionaryAsync(g => g.Key, g => g.Select(cr => cr.CaregiverId).ToList());

        // 6c: Process each instance — determine action via time-based escalation
        var reminderNotifications = new List<BatchNotification>();
        var missedInstances = new List<ReminderInstance>();
        var escalatedInstances = new List<(ReminderInstance Instance, int NewLevel)>();

        foreach (var instance in dueInstances)
        {
            var reminder = instance.Reminder;
            var dependent = reminder.Dependent;

            // Handle snooze: if snoozed and snooze elapsed, clear snooze
            DateTime? capturedSnoozedUntil = null;
            if (instance.Status == "snoozed" && instance.SnoozedUntil.HasValue)
            {
                var snoozedUntilUtc = DateTime.SpecifyKind(instance.SnoozedUntil.Value, DateTimeKind.Utc);
                if (now < snoozedUntilUtc)
                {
                    // Snooze hasn't elapsed yet — shouldn't happen since NextDueTime = SnoozedUntil,
                    // but guard against it
                    continue;
                }
                capturedSnoozedUntil = snoozedUntilUtc;
                instance.Status = "pending";
                instance.SnoozedUntil = null;
                instance.EscalationLevel = 0;
            }

            // Compute base time and elapsed
            var baseTime = capturedSnoozedUntil ?? DateTime.SpecifyKind(instance.ScheduledTime, DateTimeKind.Utc);
            var elapsed = (now - baseTime).TotalMinutes;

            if (elapsed >= autoMissDelay)
            {
                // Auto-miss
                instance.NextDueTime = null;
                missedInstances.Add(instance);
            }
            else if (elapsed >= 2 * escalationDelay && instance.EscalationLevel < 2)
            {
                // Level 2 escalation
                instance.EscalationLevel = 2;
                instance.NextDueTime = baseTime.AddMinutes(autoMissDelay);
                escalatedInstances.Add((instance, 2));

                reminderNotifications.Add(new BatchNotification
                {
                    UserId = dependent.Id,
                    Title = GetNotificationTitle(reminder.Title, 2),
                    Body = GetNotificationBody(reminder.Description, 2),
                    Data = BuildNotificationData(instance, reminder, 2)
                });
            }
            else if (elapsed >= escalationDelay && instance.EscalationLevel < 1)
            {
                // Level 1 escalation
                instance.EscalationLevel = 1;
                instance.NextDueTime = baseTime.AddMinutes(2 * escalationDelay);
                escalatedInstances.Add((instance, 1));

                reminderNotifications.Add(new BatchNotification
                {
                    UserId = dependent.Id,
                    Title = GetNotificationTitle(reminder.Title, 1),
                    Body = GetNotificationBody(reminder.Description, 1),
                    Data = BuildNotificationData(instance, reminder, 1)
                });
            }
            else
            {
                // Level 0 (initial notification)
                instance.EscalationLevel = 0;
                instance.NextDueTime = baseTime.AddMinutes(escalationDelay);
                escalatedInstances.Add((instance, 0));

                reminderNotifications.Add(new BatchNotification
                {
                    UserId = dependent.Id,
                    Title = GetNotificationTitle(reminder.Title, 0),
                    Body = GetNotificationBody(reminder.Description, 0),
                    Data = BuildNotificationData(instance, reminder, 0)
                });
            }
        }

        // 6d: Batch-send dependent notifications
        List<NotificationResult>? sendResults = null;
        if (reminderNotifications.Count > 0)
        {
            sendResults = await notificationService.SendBatchToUsersAsync(reminderNotifications);
        }

        // 6e: Handle missed instances — delegate to MarkAsMissedAsync for caregiver notifications
        foreach (var instance in missedInstances)
        {
            try
            {
                await MarkAsMissedAsync(instance.Id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Tick processor: error marking instance {InstanceId} as missed", instance.Id);
            }
        }

        // 6f: Batch-log notifications
        if (sendResults != null)
        {
            for (var i = 0; i < reminderNotifications.Count; i++)
            {
                var n = reminderNotifications[i];
                var result = sendResults[i];
                var escalationLevel = 0;
                if (n.Data != null && n.Data.TryGetValue("escalationLevel", out var lvlStr))
                    int.TryParse(lvlStr, out escalationLevel);

                var referenceId = n.Data?.GetValueOrDefault("instanceId") ?? "";

                var log = new NotificationLog
                {
                    UserId = n.UserId,
                    Type = "reminder",
                    ReferenceId = referenceId,
                    Title = n.Title,
                    Body = n.Body,
                    Payload = JsonSerializer.Serialize(n.Data),
                    EscalationLevel = escalationLevel,
                    ScheduledAt = DateTime.UtcNow,
                    SentAt = DateTime.UtcNow,
                    Status = result.Success ? "sent" : "failed",
                    ErrorMessage = result.Error,
                    FcmMessageId = result.MessageId
                };
                context.NotificationLogs.Add(log);
            }
        }

        // 6g: Batch-save all state changes (1 DB write)
        await context.SaveChangesAsync();

        // 6h: Send SignalR events for escalation changes
        foreach (var (instance, newLevel) in escalatedInstances)
        {
            var dependentId = instance.Reminder.DependentId;
            var instanceDto = new
            {
                instanceId = instance.Id,
                status = instance.Status,
                escalationLevel = instance.EscalationLevel
            };

            await hubContext.Clients.User(dependentId).SendAsync("InstanceStatusChanged", instanceDto);

            if (caregiverMap.TryGetValue(dependentId, out var cgIds))
            {
                foreach (var caregiverId in cgIds)
                    await hubContext.Clients.User(caregiverId).SendAsync("InstanceStatusChanged", instanceDto);
            }

            await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceStatusChanged", instanceDto);
        }

        _logger.LogInformation(
            "Tick processor: processed {Total} instances, sent {Notifications} notifications, missed {Missed}",
            dueInstances.Count, reminderNotifications.Count, missedInstances.Count);
    }

    private static Dictionary<string, string> BuildNotificationData(ReminderInstance instance, Reminder reminder, int escalationLevel)
    {
        return new Dictionary<string, string>
        {
            { "type", "reminder" },
            { "instanceId", instance.Id },
            { "reminderId", reminder.Id },
            { "priority", reminder.Priority },
            { "escalationLevel", escalationLevel.ToString() },
            { "click_action", "OPEN_REMINDER" }
        };
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

        // Skip if the parent reminder has been deleted (soft-deleted)
        if (instance.Reminder == null || !instance.Reminder.IsActive)
        {
            _logger.LogInformation("Skipping notification for {InstanceId} - reminder is inactive/deleted", instanceId);
            return;
        }

        // Skip if already completed or missed
        if (instance.Status == "completed" || instance.Status == "missed")
        {
            _logger.LogInformation("Skipping notification for {InstanceId} - status is {Status}", instanceId, instance.Status);
            return;
        }

        // Capture SnoozedUntil before clearing so chaining can compute escalation times relative to snooze end
        DateTime? capturedSnoozedUntil = null;

        // If snoozed and snooze window hasn't elapsed yet, skip sending.
        // (Jobs should be rescheduled on snooze, but this guards against race conditions.)
        if (instance.Status == "snoozed" && instance.SnoozedUntil.HasValue)
        {
            var snoozedUntilUtc = DateTime.SpecifyKind(instance.SnoozedUntil.Value, DateTimeKind.Utc);
            if (DateTime.UtcNow < snoozedUntilUtc)
            {
                _logger.LogInformation(
                    "Skipping notification for {InstanceId} - snoozed until {SnoozedUntilUtc}",
                    instanceId, snoozedUntilUtc);
                return;
            }

            capturedSnoozedUntil = snoozedUntilUtc;

            // Snooze window elapsed: transition back to pending so escalations behave normally.
            instance.Status = "pending";
            instance.SnoozedUntil = null;
            await context.SaveChangesAsync();
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

            // Query caregivers directly from database to ensure SignalR delivery
            var caregiverIds = await context.CareRelationships
                .Where(cr => cr.DependentId == dependent.Id && cr.Status == "active")
                .Select(cr => cr.CaregiverId)
                .ToListAsync();

            var instanceDto = new
            {
                instanceId = instance.Id,
                status = instance.Status,
                escalationLevel = instance.EscalationLevel
            };

            // Notify via SignalR - send directly to dependent and each caregiver via Clients.User()
            var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<SyncHub>>();
            await hubContext.Clients.User(dependent.Id).SendAsync("InstanceStatusChanged", instanceDto);

            foreach (var caregiverId in caregiverIds)
            {
                await hubContext.Clients.User(caregiverId).SendAsync("InstanceStatusChanged", instanceDto);
            }

            // Also send to dependent group as fallback (for subscribed caregivers)
            await hubContext.Clients.Group($"dependent:{dependent.Id}").SendAsync("InstanceStatusChanged", instanceDto);
        }

        // Chain next escalation step if instance is still pending
        if (instance.Status == "pending")
        {
            var escalationDelay = _configuration.GetValue<int>("Notifications:EscalationDelayMinutes", 5);
            var autoMissDelay = _configuration.GetValue<int>("Notifications:AutoMissDelayMinutes", 30);

            // Cancel any remaining pre-scheduled jobs (backward compat with old 4-job instances)
            if (!string.IsNullOrEmpty(instance.NotificationJobIds))
            {
                try
                {
                    var oldJobIds = JsonSerializer.Deserialize<List<string>>(instance.NotificationJobIds);
                    if (oldJobIds != null)
                    {
                        foreach (var jobId in oldJobIds)
                            BackgroundJob.Delete(jobId);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error cancelling old jobs for instance {InstanceId}", instanceId);
                }
            }

            // Compute base time: use snooze end if snoozed, otherwise original scheduled time
            var baseTime = capturedSnoozedUntil ?? DateTime.SpecifyKind(instance.ScheduledTime, DateTimeKind.Utc);
            string? chainedJobId = null;

            if (escalationLevel < 2)
            {
                // Chain to next escalation level
                var nextLevel = escalationLevel + 1;
                var nextTime = baseTime.AddMinutes(escalationDelay * nextLevel);
                if (nextTime <= DateTime.UtcNow)
                    nextTime = DateTime.UtcNow.AddSeconds(1);

                chainedJobId = BackgroundJob.Schedule<INotificationJobService>(
                    x => x.SendReminderNotificationAsync(instanceId, nextLevel),
                    nextTime
                );
                _logger.LogInformation(
                    "Chained escalation level {NextLevel} for instance {InstanceId} at {NextTime}",
                    nextLevel, instanceId, nextTime);
            }
            else
            {
                // Level 2 → chain to auto-miss
                var missTime = baseTime.AddMinutes(autoMissDelay);
                if (missTime <= DateTime.UtcNow)
                    missTime = DateTime.UtcNow.AddSeconds(1);

                chainedJobId = BackgroundJob.Schedule<INotificationJobService>(
                    x => x.MarkAsMissedAsync(instanceId),
                    missTime
                );
                _logger.LogInformation(
                    "Chained auto-miss for instance {InstanceId} at {MissTime}",
                    instanceId, missTime);
            }

            // Update NotificationJobIds to contain only the single chained job
            instance.NotificationJobIds = JsonSerializer.Serialize(new List<string> { chainedJobId });
            await context.SaveChangesAsync();
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
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var instance = await context.ReminderInstances
            .Include(i => i.Reminder)
            .ThenInclude(r => r.Dependent)
            .FirstOrDefaultAsync(i => i.Id == instanceId);

        if (instance == null)
        {
            _logger.LogWarning("Reminder instance {InstanceId} not found for auto-miss", instanceId);
            return;
        }

        // Skip if the parent reminder has been deleted (soft-deleted)
        if (instance.Reminder == null || !instance.Reminder.IsActive)
        {
            _logger.LogInformation("Skipping auto-miss for {InstanceId} - reminder is inactive/deleted", instanceId);
            return;
        }

        // Skip if already completed
        if (instance.Status == "completed")
        {
            _logger.LogInformation("Skipping auto-miss for {InstanceId} - already completed", instanceId);
            return;
        }

        // If not already missed, transition to missed.
        // If already missed, we still may need to send caregiver notifications (e.g. when status was
        // set by an alternate path like "missed on fetch" but push failed/never ran).
        if (instance.Status != "missed")
        {
            instance.Status = "missed";
            await context.SaveChangesAsync();
        }

        var dependentId = instance.Reminder.DependentId;
        var dependentName = instance.Reminder.Dependent?.Name;
        var reminderTitle = instance.Reminder.Title;

        // Query caregivers directly from database to ensure SignalR delivery
        var caregiverIds = await context.CareRelationships
            .Where(cr => cr.DependentId == dependentId && cr.Status == "active")
            .Select(cr => cr.CaregiverId)
            .ToListAsync();

        // Push notification to caregivers (standard tray notification).
        if (caregiverIds.Count > 0)
        {
            var title = string.IsNullOrWhiteSpace(dependentName)
                ? $"Missed: {reminderTitle}"
                : $"{dependentName} missed: {reminderTitle}";
            var body = "Reminder was missed";

            var data = new Dictionary<string, string>
            {
                { "type", "reminder_missed" },
                { "instanceId", instance.Id },
                { "reminderId", instance.ReminderId },
                { "dependentId", dependentId },
                { "status", "missed" }
            };

            foreach (var caregiverId in caregiverIds)
            {
                // Idempotency: don't spam duplicates if already successfully sent for this caregiver+instance.
                var alreadySent = await context.NotificationLogs.AnyAsync(n =>
                    n.UserId == caregiverId &&
                    n.Type == "reminder_missed" &&
                    n.ReferenceId == instance.Id &&
                    n.Status == "sent");

                if (alreadySent)
                {
                    continue;
                }

                var result = await notificationService.SendToUserAsync(caregiverId, title, body, data);
                await LogNotificationAsync(context, caregiverId, "reminder_missed", instance.Id, title, body, data, 0, result);
            }
        }

        var instanceDto = new
        {
            instanceId = instance.Id,
            status = instance.Status,
            escalationLevel = instance.EscalationLevel
        };

        // Notify via SignalR - send directly to dependent and each caregiver via Clients.User()
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<SyncHub>>();
        await hubContext.Clients.User(dependentId).SendAsync("InstanceStatusChanged", instanceDto);

        foreach (var caregiverId in caregiverIds)
        {
            await hubContext.Clients.User(caregiverId).SendAsync("InstanceStatusChanged", instanceDto);
        }

        // Also send to dependent group as fallback
        await hubContext.Clients.Group($"dependent:{dependentId}").SendAsync("InstanceStatusChanged", instanceDto);

        _logger.LogInformation("Auto-marked instance {InstanceId} as missed, notified dependent and {CaregiverCount} caregivers",
            instanceId, caregiverIds.Count);
    }

    public async Task ScheduleNotificationJobsAsync(string instanceId, DateTime scheduledTimeUtc)
    {
        var jobIds = new List<string>();

        // Only schedule if the time is in the future
        if (scheduledTimeUtc > DateTime.UtcNow)
        {
            // Schedule only the level-0 notification; escalations are chained from SendReminderNotificationAsync
            var job1 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.SendReminderNotificationAsync(instanceId, 0),
                scheduledTimeUtc
            );
            jobIds.Add(job1);

            _logger.LogInformation(
                "Scheduled level-0 notification job for instance {InstanceId} at {Time}",
                instanceId, scheduledTimeUtc);
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

    public async Task CancelReminderNotificationJobsAsync(string reminderId)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var instances = await context.ReminderInstances
            .Where(i => i.ReminderId == reminderId && (i.Status == "pending" || i.Status == "snoozed"))
            .ToListAsync();

        if (instances.Count == 0)
        {
            return;
        }

        var cancelledJobs = 0;
        foreach (var instance in instances)
        {
            if (string.IsNullOrEmpty(instance.NotificationJobIds))
            {
                continue;
            }

            try
            {
                var jobIds = JsonSerializer.Deserialize<List<string>>(instance.NotificationJobIds);
                if (jobIds != null)
                {
                    foreach (var jobId in jobIds)
                    {
                        BackgroundJob.Delete(jobId);
                        cancelledJobs++;
                    }
                }

                instance.NotificationJobIds = null;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error cancelling jobs for instance {InstanceId}", instance.Id);
            }
        }

        await context.SaveChangesAsync();
        _logger.LogInformation(
            "Cancelled {JobCount} jobs for {InstanceCount} instances of reminder {ReminderId}",
            cancelledJobs, instances.Count, reminderId);
    }

    public async Task ProcessReminderNotificationsAsync(string reminderId)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var instances = await context.ReminderInstances
            .Where(i => i.ReminderId == reminderId && i.ScheduledTime > DateTime.UtcNow)
            .ToListAsync();

        if (instances.Count == 0)
        {
            _logger.LogInformation("No future instances found for reminder {ReminderId}", reminderId);
            return;
        }

        foreach (var instance in instances)
        {
            var scheduledTimeUtc = instance.ScheduledTime;

            // Schedule only level-0 job; escalations are chained from SendReminderNotificationAsync
            var job1 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.SendReminderNotificationAsync(instance.Id, 0),
                scheduledTimeUtc
            );

            instance.NotificationJobIds = JsonSerializer.Serialize(new List<string> { job1 });
        }

        // Single batch save for all job IDs
        await context.SaveChangesAsync();

        _logger.LogInformation(
            "Scheduled level-0 notification jobs for {Count} instances of reminder {ReminderId}",
            instances.Count, reminderId);
    }

    public async Task RescheduleReminderNotificationsAsync(string reminderId)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var instances = await context.ReminderInstances
            .Where(i => i.ReminderId == reminderId && i.ScheduledTime > DateTime.UtcNow)
            .ToListAsync();

        if (instances.Count == 0)
        {
            _logger.LogInformation("No future instances found for reminder {ReminderId} to reschedule", reminderId);
            return;
        }

        // Cancel all existing jobs first
        foreach (var instance in instances)
        {
            if (!string.IsNullOrEmpty(instance.NotificationJobIds))
            {
                try
                {
                    var oldJobIds = JsonSerializer.Deserialize<List<string>>(instance.NotificationJobIds);
                    if (oldJobIds != null)
                    {
                        foreach (var jobId in oldJobIds)
                        {
                            BackgroundJob.Delete(jobId);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error parsing job IDs for instance {InstanceId}", instance.Id);
                }
            }
        }

        // Schedule new level-0 jobs for all instances; escalations are chained at runtime
        foreach (var instance in instances)
        {
            var scheduledTimeUtc = instance.ScheduledTime;

            var job1 = BackgroundJob.Schedule<INotificationJobService>(
                x => x.SendReminderNotificationAsync(instance.Id, 0),
                scheduledTimeUtc
            );

            instance.NotificationJobIds = JsonSerializer.Serialize(new List<string> { job1 });
        }

        // Single batch save for all job IDs
        await context.SaveChangesAsync();

        _logger.LogInformation(
            "Rescheduled level-0 notification jobs for {Count} instances of reminder {ReminderId}",
            instances.Count, reminderId);
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
