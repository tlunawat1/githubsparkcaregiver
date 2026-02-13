namespace ParentalCareApi.Services;

public interface IEmailService
{
    Task SendVerificationCodeAsync(string toEmail, string verificationCode, CancellationToken cancellationToken = default);
}
