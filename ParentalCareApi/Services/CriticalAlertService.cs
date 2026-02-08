using System.Text.Json;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Data;
using ParentalCareApi.Hubs;
using ParentalCareApi.Models;

namespace ParentalCareApi.Services;

public class CriticalAlertService : ICriticalAlertService
{
    private readonly AppDbContext _context;
    private readonly IVoipPushService _voipPushService;
    private readonly IHubContext<SyncHub> _hubContext;
    private readonly ILogger<CriticalAlertService> _logger;

    public CriticalAlertService(
        AppDbContext context,
        IVoipPushService voipPushService,
        IHubContext<SyncHub> hubContext,
        ILogger<CriticalAlertService> logger)
    {
        _context = context;
        _voipPushService = voipPushService;
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task TriggerSosAlertAsync(
        string dependentId,
        string? dependentName,
        string sosEventId,
        IEnumerable<string> caregiverIds)
    {
        await TriggerAlertAsync(
            type: "sos_triggered",
            dependentId: dependentId,
            dependentName: dependentName,
            referenceId: sosEventId,
            caregiverIds: caregiverIds);
    }

    public async Task TriggerUrgentReminderAsync(
        string dependentId,
        string? dependentName,
        string reminderInstanceId,
        IEnumerable<string> caregiverIds)
    {
        await TriggerAlertAsync(
            type: "reminder_urgent",
            dependentId: dependentId,
            dependentName: dependentName,
            referenceId: reminderInstanceId,
            caregiverIds: caregiverIds);
    }

    public async Task AcknowledgeAlertAsync(string alertId, string status, string acknowledgedBy)
    {
        var alert = await _context.CriticalAlerts.FirstOrDefaultAsync(a => a.Id == alertId);
        if (alert == null)
        {
            _logger.LogWarning("Critical alert {AlertId} not found for ack", alertId);
            return;
        }

        alert.Status = status;
        alert.AcknowledgedAt = DateTime.UtcNow;
        alert.AcknowledgedBy = acknowledgedBy;
        await _context.SaveChangesAsync();

        await _hubContext.Clients.User(alert.TargetUserId ?? acknowledgedBy)
            .SendAsync("CriticalAlertAcknowledged", new
            {
                alertId,
                status
            });
    }

    private async Task TriggerAlertAsync(
        string type,
        string dependentId,
        string? dependentName,
        string referenceId,
        IEnumerable<string> caregiverIds)
    {
        foreach (var caregiverId in caregiverIds)
        {
            var alertId = Guid.NewGuid().ToString();
            var payload = new Dictionary<string, object>
            {
                { "alertId", alertId },
                { "type", type },
                { "dependentId", dependentId },
                { "dependentName", dependentName ?? "Dependent" },
                { "priority", "critical" }
            };

            if (type == "sos_triggered")
            {
                payload["sosEventId"] = referenceId;
                payload["route"] = "/dependent/sos";
            }
            else
            {
                payload["instanceId"] = referenceId;
                payload["route"] = $"/dependent/reminder/{referenceId}";
            }

            var alert = new CriticalAlert
            {
                Id = alertId,
                Type = type,
                DependentId = dependentId,
                ReferenceId = referenceId,
                TargetUserId = caregiverId,
                Status = "triggered",
                Payload = JsonSerializer.Serialize(payload)
            };

            _context.CriticalAlerts.Add(alert);
            await _context.SaveChangesAsync();

            await _hubContext.Clients.User(caregiverId).SendAsync("CriticalAlertTriggered", payload);

            await SendCriticalPushesAsync(caregiverId, payload);
        }
    }

    private async Task SendCriticalPushesAsync(string caregiverId, Dictionary<string, object> payload)
    {
        var tokens = await _context.UserDeviceTokens
            .Where(t => t.UserId == caregiverId && t.IsValid)
            .ToListAsync();

        foreach (var token in tokens)
        {
            if (token.Platform == "iOS" && token.TokenType == "voip")
            {
                await _voipPushService.SendVoipPushAsync(token.Token, payload);
                continue;
            }

            var data = payload.ToDictionary(k => k.Key, v => v.Value?.ToString() ?? string.Empty);

            var message = new Message
            {
                Token = token.Token,
                Data = data,
                Android = new AndroidConfig
                {
                    Priority = Priority.High
                },
                Apns = new ApnsConfig
                {
                    Headers = new Dictionary<string, string>
                    {
                        { "apns-priority", "10" }
                    },
                    Aps = new Aps
                    {
                        ContentAvailable = true
                    }
                }
            };

            try
            {
                if (FirebaseApp.DefaultInstance != null)
                {
                    await FirebaseMessaging.DefaultInstance.SendAsync(message);
                }
                else
                {
                    _logger.LogInformation("Firebase not configured; critical push logged only.");
                }
            }
            catch (FirebaseMessagingException ex)
            {
                _logger.LogError(ex, "Critical push send failed for token {Token}", token.Token[..Math.Min(10, token.Token.Length)] + "...");
            }
        }
    }
}
