using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ParentalCareApi.DTOs;
using ParentalCareApi.Services;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/critical-alerts")]
[Authorize]
public class CriticalAlertsController : ControllerBase
{
    private readonly ICriticalAlertService _criticalAlertService;

    public CriticalAlertsController(ICriticalAlertService criticalAlertService)
    {
        _criticalAlertService = criticalAlertService;
    }

    [HttpPost("{id}/ack")]
    public async Task<IActionResult> AcknowledgeAlert(string id, [FromBody] AcknowledgeCriticalAlertRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null)
        {
            return Unauthorized();
        }

        await _criticalAlertService.AcknowledgeAlertAsync(id, request.Status, userId);
        return NoContent();
    }
}
