using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class Reminder
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(36)]
    public string CreatorId { get; set; } = string.Empty;

    [Required]
    [StringLength(36)]
    public string DependentId { get; set; } = string.Empty;

    [Required]
    [StringLength(200)]
    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    [StringLength(500)]
    public string? VoiceNoteUrl { get; set; }

    [Required]
    [StringLength(20)]
    public string RepeatPattern { get; set; } = "once"; // "once", "daily", "weekly", "specific_days"

    [StringLength(100)]
    public string? RepeatDays { get; set; } // JSON array like "[1,3,5]" for Mon, Wed, Fri

    [Required]
    public int Hour { get; set; }

    [Required]
    public int Minute { get; set; }

    [Required]
    [StringLength(10)]
    public string Priority { get; set; } = "normal"; // "normal", "high"

    public bool IsActive { get; set; } = true;

    public DateTime StartDate { get; set; }

    public DateTime? EndDate { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("CreatorId")]
    public User Creator { get; set; } = null!;

    [ForeignKey("DependentId")]
    public User Dependent { get; set; } = null!;
}
