using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record AcknowledgeCriticalAlertRequest(
    [Required] string Status
);
