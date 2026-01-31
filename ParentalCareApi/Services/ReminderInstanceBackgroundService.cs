using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.Hubs;
using ParentalCareApi.Models;

namespace ParentalCareApi.Services;

/// <summary>
/// Background service that manages reminder instances:
/// - Marks pending instances as "missed" if 30 minutes past scheduled time
/// - Generates future instances for recurring reminders (rolling 7-day window)
/// </summary>
public class ReminderInstanceBackgroundService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<ReminderInstanceBackgroundService> _logger;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan MissedThreshold = TimeSpan.FromMinutes(30);
    private const int RollingWindowDays = 7;

    public ReminderInstanceBackgroundService(
        IServiceProvider serviceProvider,
        ILogger<ReminderInstanceBackgroundService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("ReminderInstanceBackgroundService started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessRemindersAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in ReminderInstanceBackgroundService");
            }

            await Task.Delay(CheckInterval, stoppingToken);
        }

        _logger.LogInformation("ReminderInstanceBackgroundService stopped");
    }

    private async Task ProcessRemindersAsync(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<SyncHub>>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        // Mark missed instances
        await MarkMissedInstancesAsync(context, hubContext, stoppingToken);

        // Generate future instances for recurring reminders
        await GenerateFutureInstancesAsync(context, hubContext, stoppingToken);
    }

    private async Task MarkMissedInstancesAsync(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        CancellationToken stoppingToken)
    {
        var cutoffTime = DateTime.UtcNow.Subtract(MissedThreshold);

        var pendingInstances = await context.ReminderInstances
            .Include(i => i.Reminder)
            .Where(i => i.Status == "pending" && i.ScheduledTime < cutoffTime)
            .ToListAsync(stoppingToken);

        if (pendingInstances.Count == 0) return;

        _logger.LogInformation("Marking {Count} instances as missed", pendingInstances.Count);

        foreach (var instance in pendingInstances)
        {
            instance.Status = "missed";

            var instanceDto = new
            {
                instance.Id,
                instance.ReminderId,
                instance.ScheduledTime,
                instance.Status,
                instance.CompletedAt,
                instance.SnoozedUntil,
                instance.EscalationLevel,
                instance.CreatedAt,
                ReminderTitle = instance.Reminder?.Title,
                ReminderDescription = instance.Reminder?.Description,
                VoiceNoteUrl = instance.Reminder?.VoiceNoteUrl,
                Priority = instance.Reminder?.Priority
            };

            await hubContext.SendInstanceStatusChangedAsync(
                instance.Reminder?.DependentId ?? "",
                instanceDto);
        }

        await context.SaveChangesAsync(stoppingToken);
    }

    private async Task GenerateFutureInstancesAsync(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        CancellationToken stoppingToken)
    {
        var today = DateTime.UtcNow.Date;
        var windowEnd = today.AddDays(RollingWindowDays);

        // Get all active recurring reminders
        var recurringReminders = await context.Reminders
            .Where(r => r.IsActive &&
                        r.RepeatPattern != "once" &&
                        (r.EndDate == null || r.EndDate >= today))
            .ToListAsync(stoppingToken);

        foreach (var reminder in recurringReminders)
        {
            await GenerateInstancesForReminderAsync(context, hubContext, reminder, today, windowEnd, stoppingToken);
        }
    }

    private async Task GenerateInstancesForReminderAsync(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        Reminder reminder,
        DateTime today,
        DateTime windowEnd,
        CancellationToken stoppingToken)
    {
        // Get existing instance dates for this reminder
        var existingDates = await context.ReminderInstances
            .Where(i => i.ReminderId == reminder.Id && i.ScheduledTime >= today)
            .Select(i => i.ScheduledTime.Date)
            .ToListAsync(stoppingToken);

        var existingDateSet = new HashSet<DateTime>(existingDates);
        var startDate = reminder.StartDate.Date >= today ? reminder.StartDate.Date : today;
        var endDate = reminder.EndDate?.Date ?? windowEnd;
        endDate = endDate < windowEnd ? endDate : windowEnd;

        var newInstances = new List<ReminderInstance>();

        switch (reminder.RepeatPattern.ToLower())
        {
            case "daily":
                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    if (!existingDateSet.Contains(date))
                    {
                        newInstances.Add(CreateInstance(reminder, date));
                    }
                }
                break;

            case "weekly":
                var targetDayOfWeek = reminder.StartDate.DayOfWeek;
                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    if (date.DayOfWeek == targetDayOfWeek && !existingDateSet.Contains(date))
                    {
                        newInstances.Add(CreateInstance(reminder, date));
                    }
                }
                break;

            case "specific_days":
                if (!string.IsNullOrEmpty(reminder.RepeatDays))
                {
                    try
                    {
                        var days = System.Text.Json.JsonSerializer.Deserialize<int[]>(reminder.RepeatDays) ?? [];
                        for (var date = startDate; date <= endDate; date = date.AddDays(1))
                        {
                            if (days.Contains((int)date.DayOfWeek) && !existingDateSet.Contains(date))
                            {
                                newInstances.Add(CreateInstance(reminder, date));
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to parse RepeatDays for reminder {ReminderId}", reminder.Id);
                    }
                }
                break;
        }

        if (newInstances.Count > 0)
        {
            context.ReminderInstances.AddRange(newInstances);
            await context.SaveChangesAsync(stoppingToken);
            _logger.LogInformation("Generated {Count} new instances for reminder {ReminderId}", newInstances.Count, reminder.Id);

            // Notify dependent about new instances
            foreach (var instance in newInstances)
            {
                var instanceDto = new
                {
                    instance.Id,
                    instance.ReminderId,
                    instance.ScheduledTime,
                    instance.Status,
                    instance.CompletedAt,
                    instance.SnoozedUntil,
                    instance.EscalationLevel,
                    instance.CreatedAt,
                    ReminderTitle = reminder.Title,
                    ReminderDescription = reminder.Description,
                    VoiceNoteUrl = reminder.VoiceNoteUrl,
                    Priority = reminder.Priority
                };
                await hubContext.SendInstanceCreatedAsync(reminder.DependentId, instanceDto);
            }
        }
    }

    private static ReminderInstance CreateInstance(Reminder reminder, DateTime date)
    {
        return new ReminderInstance
        {
            Id = Guid.NewGuid().ToString(),
            ReminderId = reminder.Id,
            ScheduledTime = date.AddHours(reminder.Hour).AddMinutes(reminder.Minute),
            Status = "pending",
            EscalationLevel = 0,
            CreatedAt = DateTime.UtcNow
        };
    }
}
