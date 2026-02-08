namespace ParentalCareApi.Services;

public class ApnsVoipOptions
{
    public string? TeamId { get; set; }
    public string? KeyId { get; set; }
    public string? BundleId { get; set; }
    public string? PrivateKey { get; set; } // p8 contents
    public bool UseSandbox { get; set; } = false;
}
