using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace ParentalCareApi.Services;

public class VoipPushService : IVoipPushService
{
    private readonly HttpClient _httpClient;
    private readonly ApnsVoipOptions _options;
    private readonly ILogger<VoipPushService> _logger;

    public VoipPushService(
        HttpClient httpClient,
        IOptions<ApnsVoipOptions> options,
        ILogger<VoipPushService> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;
    }

    public async Task SendVoipPushAsync(string deviceToken, Dictionary<string, object> payload)
    {
        if (string.IsNullOrWhiteSpace(deviceToken))
        {
            _logger.LogWarning("VoIP push skipped: missing device token");
            return;
        }

        if (string.IsNullOrWhiteSpace(_options.TeamId) ||
            string.IsNullOrWhiteSpace(_options.KeyId) ||
            string.IsNullOrWhiteSpace(_options.BundleId) ||
            string.IsNullOrWhiteSpace(_options.PrivateKey))
        {
            _logger.LogWarning("VoIP push skipped: APNs VoIP config not set");
            return;
        }

        var host = _options.UseSandbox
            ? "https://api.sandbox.push.apple.com"
            : "https://api.push.apple.com";
        var url = $"{host}/3/device/{deviceToken}";

        var jwt = CreateJwt(_options.TeamId, _options.KeyId, _options.PrivateKey);
        var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Version = new Version(2, 0);
        request.Headers.Authorization = new AuthenticationHeaderValue("bearer", jwt);
        request.Headers.Add("apns-push-type", "voip");
        request.Headers.Add("apns-topic", $"{_options.BundleId}.voip");
        request.Headers.Add("apns-priority", "10");
        request.Headers.Add("apns-expiration", "0");

        var body = JsonSerializer.Serialize(payload);
        request.Content = new StringContent(body, Encoding.UTF8, "application/json");

        var response = await _httpClient.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var responseBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("VoIP push failed: {Status} {Body}", response.StatusCode, responseBody);
        }
        else
        {
            _logger.LogInformation("VoIP push sent successfully");
        }
    }

    private static string CreateJwt(string teamId, string keyId, string privateKeyPem)
    {
        var header = Base64UrlEncode(JsonSerializer.Serialize(new
        {
            alg = "ES256",
            kid = keyId
        }));

        var payload = Base64UrlEncode(JsonSerializer.Serialize(new
        {
            iss = teamId,
            iat = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        }));

        var unsignedToken = $"{header}.{payload}";
        var signature = Sign(unsignedToken, privateKeyPem);

        return $"{unsignedToken}.{signature}";
    }

    private static string Sign(string data, string privateKeyPem)
    {
        var key = privateKeyPem
            .Replace("-----BEGIN PRIVATE KEY-----", string.Empty)
            .Replace("-----END PRIVATE KEY-----", string.Empty)
            .Replace("\n", string.Empty)
            .Replace("\r", string.Empty)
            .Trim();

        var privateKeyBytes = Convert.FromBase64String(key);
        using var ecdsa = ECDsa.Create();
        ecdsa.ImportPkcs8PrivateKey(privateKeyBytes, out _);
        var signature = ecdsa.SignData(Encoding.UTF8.GetBytes(data), HashAlgorithmName.SHA256);
        return Base64UrlEncode(signature);
    }

    private static string Base64UrlEncode(string input)
    {
        return Base64UrlEncode(Encoding.UTF8.GetBytes(input));
    }

    private static string Base64UrlEncode(byte[] input)
    {
        return Convert.ToBase64String(input)
            .Replace("+", "-")
            .Replace("/", "_")
            .Replace("=", string.Empty);
    }
}
