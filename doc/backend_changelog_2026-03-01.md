# Backend Changelog — 2026-03-01 (Branch: archChanges)

## Summary

Architectural overhaul of the notification and instance-generation subsystems. Replaces the per-instance 4-job Hangfire scheduling model with a **tick-based polling processor** and **chained escalation jobs**, reducing Hangfire job volume by ~75%. Also narrows the instance rolling window from 7 days to 2 days and adds batch FCM sending.

---

## Changes by File

### 1. `Models/Reminder.cs`
- **Added** `NextInstanceDate` (nullable `DateTime`) property.
  - Used by the background service to skip reminders that already have instances generated up to the current window edge.
  - Prevents redundant regeneration on every 30-minute tick.

### 2. `Models/ReminderInstance.cs`
- **Added** `NextDueTime` (nullable `DateTime`) property.
  - Drives the tick processor: when non-null and `<= DateTime.UtcNow`, the instance is picked up for notification processing.
  - Set to `null` once the instance is completed, missed, or no longer needs processing.

### 3. `Data/AppDbContext.cs`
- **Added** index on `Reminders.NextInstanceDate` for efficient background service queries.

### 4. `Program.cs` — Schema Migrations & Hangfire Setup
- **Added** SQL migration to create `Reminders.NextInstanceDate` column (with index) if it doesn't exist.
- **Added** Hangfire recurring job registration:
  - `"process-due-notifications"` — calls `ProcessDueNotificationsAsync()` every minute (`"* * * * *"` cron).

### 5. `Services/INotificationJobService.cs`
- **Added** `ProcessDueNotificationsAsync()` to the interface.
  - Entry point for the tick-based notification processor invoked by the Hangfire recurring job.

### 6. `Services/NotificationJobService.cs` — Major Refactor

#### New: `ProcessDueNotificationsAsync()` (Tick Processor)
End-to-end batch notification pipeline in a single method:
1. **Query** all `ReminderInstance` rows where `NextDueTime <= now` and status is `pending` or `snoozed` (1 DB query).
2. **Batch-load** caregiver relationships for all affected dependents (1 DB query).
3. **Classify** each instance by time-elapsed since `ScheduledTime` (or `SnoozedUntil`):
   - `>= AutoMissDelay (30 min)` → mark as missed, set `NextDueTime = null`.
   - `>= 2 × EscalationDelay (10 min)` → escalate to level 2, set `NextDueTime` to auto-miss time.
   - `>= EscalationDelay (5 min)` → escalate to level 1, set `NextDueTime` to level 2 time.
   - `< EscalationDelay` → level 0 initial notification, set `NextDueTime` to level 1 time.
4. **Batch-send** dependent notifications via `SendBatchToUsersAsync()`.
5. **Delegate** missed instances to existing `MarkAsMissedAsync()` for caregiver alerts.
6. **Batch-log** all notification results to `NotificationLogs`.
7. **Batch-save** all state changes in a single `SaveChangesAsync()` call.
8. **Broadcast** `InstanceStatusChanged` SignalR events to dependents and caregivers.

#### Modified: `SendReminderNotificationAsync()`
- **Added** chained escalation logic after sending a notification:
  - Cancels any leftover pre-scheduled Hangfire jobs (backward compat).
  - Chains a single next-step job (next escalation level or auto-miss) instead of relying on the upfront 4-job schedule.
  - Stores only the single chained job ID in `NotificationJobIds`.
- **Added** snooze-aware base time: computes escalation delays relative to `SnoozedUntil` end when resuming from snooze.

#### Modified: `ScheduleNotificationJobsAsync()`
- **Reduced** from 4 upfront jobs (level 0, level 1, level 2, auto-miss) to **1 job** (level 0 only).
- Escalations are now chained at runtime from `SendReminderNotificationAsync()`.

#### Modified: `ScheduleNotificationJobsForReminderAsync()`
- Same reduction: schedules only the level-0 job per instance.
- Single batch `SaveChangesAsync()` for all job IDs.

#### Modified: `RescheduleNotificationJobsAsync()`
- Same reduction: cancels old jobs, schedules only level-0 per instance.

#### Added: `BuildNotificationData()` (private helper)
- Constructs the FCM data dictionary for a reminder notification (type, instanceId, reminderId, priority, escalationLevel, click_action).

### 7. `Services/INotificationService.cs`
- **Added** `SendBatchToUsersAsync(IList<BatchNotification>)` method.
- **Added** `BatchNotification` class (UserId, Title, Body, Data).

### 8. `Services/NotificationService.cs` — Refactor + Batch Support

#### New: `SendBatchToUsersAsync()`
- Resolves device tokens for all target users in a single DB query.
- Falls back to legacy `User.DeviceToken` for users without entries in `UserDeviceTokens`.
- Builds FCM messages for all tokens, sends in chunks of 500 via `FirebaseMessaging.SendEachAsync()`.
- Collects per-notification success/failure counts and invalidates unregistered tokens.

#### Refactored: `SendPushNotificationAsync()`
- **Extracted** FCM message construction into `BuildFcmMessage()` private method.
- Now delegates to `BuildFcmMessage()` and sends the single message.

#### New: `BuildFcmMessage()` (private)
- Contains all Android/iOS-specific FCM configuration:
  - Android: high priority, collapse key per instance+escalation, channel routing, data-only for urgent escalation.
  - iOS (APNS): priority 10, sound routing (default vs. `reminder_alarm.caf`), badge, content-available.
- Clones the data dictionary to avoid mutating the caller's reference.

### 9. `Controllers/ReminderInstancesController.cs`
- **Added** `NextDueTime = request.ScheduledTime` when creating instances manually.
- **Removed** fire-and-forget `Task.Run` that scheduled Hangfire jobs per instance.
  - Comment: "Tick processor handles notifications via NextDueTime — no per-instance Hangfire jobs needed."

### 10. `Controllers/RemindersController.cs`
- **Rolling window reduced**: 7 days → 2 days for `GenerateInstancesForReminder()` and update-path regeneration.
- **Added** `NextInstanceDate` update after creating a reminder (set to `today + 2 days`).
- **Added** `NextInstanceDate` update after editing a reminder's schedule.

### 11. `Services/ReminderInstanceBackgroundService.cs`
- **Rolling window reduced**: 7 days → 2 days (`RollingWindowDays = 2`).
- **Check interval increased**: 5 minutes → 30 minutes (`CheckInterval = TimeSpan.FromMinutes(30)`).
- **Added** `NextInstanceDate` filter to the recurring reminders query:
  - Only processes reminders where `NextInstanceDate` is null (never processed) or `< windowEnd`.
- **Added** `NextInstanceDate = windowEnd` update after generating instances for each reminder.
- **Added** batch `SaveChangesAsync()` for all `NextInstanceDate` updates.

---

## Architecture: Before vs After

### Before (Per-Instance Upfront Scheduling)
```
Reminder Created
  └─ Generate instances (7-day window)
      └─ Per instance: schedule 4 Hangfire jobs
          ├─ Level 0 at ScheduledTime
          ├─ Level 1 at +5 min
          ├─ Level 2 at +10 min
          └─ Auto-miss at +30 min
```
- **Problem**: 4 jobs × N instances = high Hangfire storage and contention.
- **Problem**: Snooze requires cancelling and rescheduling all 4 jobs.

### After (Tick Processor + Chained Escalation)
```
Reminder Created
  └─ Generate instances (2-day window)
      └─ Set NextDueTime = ScheduledTime (no Hangfire jobs)

Every 1 minute (Hangfire recurring):
  └─ ProcessDueNotificationsAsync()
      ├─ Query instances where NextDueTime <= now
      ├─ Classify by elapsed time → determine escalation level
      ├─ Batch-send FCM notifications
      ├─ Update NextDueTime to next escalation step (or null for missed)
      └─ Batch-save + SignalR broadcast
```
- **Benefit**: 0 upfront jobs for tick-processed instances; 1 recurring job handles all.
- **Benefit**: Snooze simply sets `NextDueTime = SnoozedUntil`; tick processor picks it up naturally.
- **Fallback**: `SendReminderNotificationAsync()` still supports chained Hangfire jobs for any instances created via the old path.

---

## Database Changes

| Table | Column | Type | Purpose |
|-------|--------|------|---------|
| `Reminders` | `NextInstanceDate` | `DATETIME2 NULL` | Background service optimization — skip already-processed reminders |
| `Reminders` | `IX_Reminders_NextInstanceDate` | Index | Efficient filtering in background service query |
| `ReminderInstances` | `NextDueTime` | `DATETIME? NULL` | Tick processor polling column |

**Migration**: Auto-applied via `Program.cs` raw SQL (`IF NOT EXISTS` guard).

---

## Configuration Changes

No changes to `appsettings.json`. Existing values are used:
- `Notifications:EscalationDelayMinutes` (default: 5)
- `Notifications:AutoMissDelayMinutes` (default: 30)

---

## Risk & Backward Compatibility

- **Old instances with 4 pre-scheduled jobs**: The chained escalation path in `SendReminderNotificationAsync()` cancels leftover old jobs before scheduling the next step. No double-send risk.
- **`NextDueTime` column**: Nullable, so existing instances without the column default to `null` and are ignored by the tick processor. They continue to work via existing Hangfire jobs.
- **`NextInstanceDate` column**: Nullable, so existing reminders default to `null` and are treated as "never processed" — the background service will generate instances for them on the next tick.
