using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace ParentalCareApi.Services;

public interface IBlobStorageService
{
    Task<string> UploadAsync(Stream stream, string fileName, string contentType);
}

public class BlobStorageService : IBlobStorageService
{
    private readonly BlobContainerClient _containerClient;
    private readonly ILogger<BlobStorageService> _logger;

    public BlobStorageService(IConfiguration configuration, ILogger<BlobStorageService> logger)
    {
        _logger = logger;

        // Support both key styles during migration; prefer AzureStorage.
        var connectionString = configuration["AzureStorage:ConnectionString"]
            ?? configuration["Azure:BlobStorage:ConnectionString"]
            ?? throw new InvalidOperationException("Azure Storage connection string not configured");

        var containerName = configuration["AzureStorage:ContainerName"]
            ?? configuration["Azure:BlobStorage:ContainerName"]
            ?? "uploads";

        var blobServiceClient = new BlobServiceClient(connectionString);
        _containerClient = blobServiceClient.GetBlobContainerClient(containerName);
    }

    public async Task<string> UploadAsync(Stream stream, string fileName, string contentType)
    {
        try
        {
            // Ensure container exists
            await _containerClient.CreateIfNotExistsAsync(PublicAccessType.Blob);

            var blobClient = _containerClient.GetBlobClient(fileName);

            var blobHttpHeaders = new BlobHttpHeaders
            {
                ContentType = contentType
            };

            await blobClient.UploadAsync(stream, new BlobUploadOptions
            {
                HttpHeaders = blobHttpHeaders
            });

            _logger.LogInformation("Uploaded blob: {FileName}", fileName);

            return blobClient.Uri.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading blob: {FileName}", fileName);
            throw;
        }
    }
}
