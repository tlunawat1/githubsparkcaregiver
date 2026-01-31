using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ParentalCareApi.Services;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/files")]
[Authorize]
public class FilesController : ControllerBase
{
    private readonly IBlobStorageService _blobStorageService;
    private readonly ILogger<FilesController> _logger;

    private static readonly string[] AllowedAudioExtensions = { ".m4a", ".mp3", ".wav", ".aac", ".ogg" };
    private static readonly string[] AllowedAudioContentTypes = {
        "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/mpeg", "audio/wav",
        "audio/aac", "audio/ogg", "application/octet-stream"
    };
    private const long MaxFileSizeBytes = 10 * 1024 * 1024; // 10MB

    public FilesController(IBlobStorageService blobStorageService, ILogger<FilesController> logger)
    {
        _blobStorageService = blobStorageService;
        _logger = logger;
    }

    /// <summary>
    /// Upload a voice note to Azure Blob Storage
    /// </summary>
    [HttpPost("voice-notes")]
    [RequestSizeLimit(MaxFileSizeBytes)]
    public async Task<IActionResult> UploadVoiceNote(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No file provided" });
        }

        if (file.Length > MaxFileSizeBytes)
        {
            return BadRequest(new { message = "File size exceeds the 10MB limit" });
        }

        // Validate file extension
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedAudioExtensions.Contains(extension))
        {
            return BadRequest(new { message = $"Invalid file type. Allowed types: {string.Join(", ", AllowedAudioExtensions)}" });
        }

        // Validate content type
        if (!AllowedAudioContentTypes.Contains(file.ContentType.ToLowerInvariant()))
        {
            _logger.LogWarning("Unexpected content type: {ContentType} for file: {FileName}", file.ContentType, file.FileName);
            // Allow it anyway if extension is valid (mobile clients may send different content types)
        }

        try
        {
            // Generate unique filename
            var uniqueFileName = $"voice-notes/{Guid.NewGuid()}{extension}";

            // Determine content type for storage
            var contentType = extension switch
            {
                ".m4a" => "audio/mp4",
                ".mp3" => "audio/mpeg",
                ".wav" => "audio/wav",
                ".aac" => "audio/aac",
                ".ogg" => "audio/ogg",
                _ => "audio/mp4"
            };

            using var stream = file.OpenReadStream();
            var url = await _blobStorageService.UploadAsync(stream, uniqueFileName, contentType);

            _logger.LogInformation("Voice note uploaded successfully: {Url}", url);

            return Ok(new { url });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading voice note");
            return StatusCode(500, new { message = "Failed to upload voice note" });
        }
    }
}
