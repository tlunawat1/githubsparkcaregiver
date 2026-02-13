using Azure;
using Azure.Communication.Email;
using Microsoft.Extensions.Options;

namespace ParentalCareApi.Services;

public class AzureCommunicationEmailService : IEmailService
{
    private readonly EmailClient _emailClient;
    private readonly EmailVerificationOptions _options;
    private readonly ILogger<AzureCommunicationEmailService> _logger;

    public AzureCommunicationEmailService(
        IConfiguration configuration,
        IOptions<EmailVerificationOptions> options,
        ILogger<AzureCommunicationEmailService> logger)
    {
        _options = options.Value;
        _logger = logger;

        var connectionString =
            Environment.GetEnvironmentVariable("COMMUNICATION_SERVICES_CONNECTION_STRING")
            ?? configuration["COMMUNICATION_SERVICES_CONNECTION_STRING"];

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "COMMUNICATION_SERVICES_CONNECTION_STRING is not configured.");
        }

        _emailClient = new EmailClient(connectionString);
    }

    public async Task SendVerificationCodeAsync(
        string toEmail,
        string verificationCode,
        CancellationToken cancellationToken = default)
    {
        var content = new EmailContent("Your verification code")
        {
            PlainText =
                $"Your ParentalCare verification code is {verificationCode}. " +
                $"It expires in {_options.VerificationCodeExpiryMinutes} minutes.",
            Html =
                "<html><body>" +
                "<h2>Verify your email</h2>" +
                $"<p>Your ParentalCare verification code is <strong>{verificationCode}</strong>.</p>" +
                $"<p>This code expires in {_options.VerificationCodeExpiryMinutes} minutes.</p>" +
                "<p>If you did not request this, you can safely ignore this email.</p>" +
                "</body></html>"
        };

        var message = new EmailMessage(
            senderAddress: _options.SenderAddress,
            content: content,
            recipients: new EmailRecipients(new List<EmailAddress> { new(toEmail) }));

        try
        {
            await _emailClient.SendAsync(WaitUntil.Completed, message, cancellationToken);
        }
        catch (RequestFailedException ex)
        {
            _logger.LogError(ex, "Failed to send verification email to {Email}", toEmail);
            throw;
        }
    }
}
