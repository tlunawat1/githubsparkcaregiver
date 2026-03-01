using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using NodaTime;
using ParentalCareApi.Data;
using ParentalCareApi.Hubs;
using ParentalCareApi.Models;

namespace ParentalCareApi.Services;

/// <summary>
/// Background service that manages reminder instances:
/// - Generates future instances for recurring reminders (rolling 2-day window)
/// Note: Auto-miss functionality is handled by Hangfire scheduled jobs for each instance.
/// </summary>
public class ReminderInstanceBackgroundService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<ReminderInstanceBackgroundService> _logger;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromMinutes(30);
    private const int RollingWindowDays = 2;

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
        var notificationJobService = scope.ServiceProvider.GetRequiredService<INotificationJobService>();

        // Generate future instances for recurring reminders
        await GenerateFutureInstancesAsync(context, hubContext, notificationJobService, stoppingToken);
    }

    private async Task GenerateFutureInstancesAsync(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationJobService notificationJobService,
        CancellationToken stoppingToken)
    {
        // Use UTC date for the initial query filter (conservative - includes reminders that might still be active)
        var utcToday = DateTime.UtcNow.Date;
        var utcWindowEnd = utcToday.AddDays(RollingWindowDays + 1); // +1 for timezone edge cases

        // Get active recurring reminders that need new instances generated
        // NextInstanceDate == null means never processed (e.g., after deploy); treat as needing generation
        var recurringReminders = await context.Reminders
            .Include(r => r.Dependent)
            .Where(r => r.IsActive &&
                        r.RepeatPattern != "once" &&
                        (r.EndDate == null || r.EndDate >= utcToday.AddDays(-1)) &&
                        (r.NextInstanceDate == null || r.NextInstanceDate < utcWindowEnd))
            .ToListAsync(stoppingToken);

        foreach (var reminder in recurringReminders)
        {
            // Calculate "today" based on the dependent's timezone
            var timezone = reminder.Dependent?.Timezone ?? "UTC";
            var today = GetCurrentDateInTimezone(timezone);
            var windowEnd = today.AddDays(RollingWindowDays);
            await GenerateInstancesForReminderAsync(context, hubContext, notificationJobService, reminder, today, windowEnd, stoppingToken);

            // Update NextInstanceDate so this reminder is skipped until the window advances
            reminder.NextInstanceDate = windowEnd;
        }

        // Batch-save all NextInstanceDate updates
        if (recurringReminders.Count > 0)
        {
            await context.SaveChangesAsync(stoppingToken);
        }
    }

    private async Task GenerateInstancesForReminderAsync(
        AppDbContext context,
        IHubContext<SyncHub> hubContext,
        INotificationJobService notificationJobService,
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

        // Get dependent's timezone for proper UTC conversion
        var timezone = reminder.Dependent?.Timezone ?? "UTC";

        var newInstances = new List<ReminderInstance>();

        switch (reminder.RepeatPattern.ToLower())
        {
            case "daily":
                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    if (!existingDateSet.Contains(date))
                    {
                        newInstances.Add(CreateInstance(reminder, date, timezone));
                    }
                }
                break;

            case "weekly":
                var targetDayOfWeek = reminder.StartDate.DayOfWeek;
                for (var date = startDate; date <= endDate; date = date.AddDays(1))
                {
                    if (date.DayOfWeek == targetDayOfWeek && !existingDateSet.Contains(date))
                    {
                        newInstances.Add(CreateInstance(reminder, date, timezone));
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
                                newInstances.Add(CreateInstance(reminder, date, timezone));
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

            // Query caregivers directly from database to ensure SignalR delivery
            var caregiverIds = await context.CareRelationships
                .Where(cr => cr.DependentId == reminder.DependentId && cr.Status == "active")
                .Select(cr => cr.CaregiverId)
                .ToListAsync(stoppingToken);

            // Notify dependent about new instances (tick processor handles notifications via NextDueTime)
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
                await hubContext.SendInstanceCreatedAsync(reminder.DependentId, instanceDto, caregiverIds);
            }
        }
    }

    /// <summary>
    /// Creates a ReminderInstance with proper timezone conversion.
    /// The ScheduledTime is stored in UTC.
    /// </summary>
    private static ReminderInstance CreateInstance(Reminder reminder, DateTime date, string timezone)
    {
        // Convert local time to UTC using the dependent's timezone
        var scheduledTimeUtc = NotificationJobService.ConvertToUtc(
            reminder.Hour,
            reminder.Minute,
            date,
            timezone
        );

        return new ReminderInstance
        {
            Id = Guid.NewGuid().ToString(),
            ReminderId = reminder.Id,
            ScheduledTime = scheduledTimeUtc,
            NextDueTime = scheduledTimeUtc,
            Status = "pending",
            EscalationLevel = 0,
            CreatedAt = DateTime.UtcNow
        };
    }

    /// <summary>
    /// Gets the current date in the specified timezone.
    /// This is important for determining "today" from the user's perspective.
    /// </summary>
    private static DateTime GetCurrentDateInTimezone(string timezone)
    {
        try
        {
            var tz = DateTimeZoneProviders.Tzdb.GetZoneOrNull(timezone);
            if (tz == null)
            {
                return DateTime.UtcNow.Date;
            }

            var now = SystemClock.Instance.GetCurrentInstant();
            var zonedDateTime = now.InZone(tz);
            return new DateTime(zonedDateTime.Year, zonedDateTime.Month, zonedDateTime.Day);
        }
        catch
        {
            return DateTime.UtcNow.Date;
        }
    }
}
