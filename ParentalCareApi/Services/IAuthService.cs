namespace ParentalCareApi.Services;

public interface IAuthService
{
    string HashPassword(string password);
    bool VerifyPassword(string password, string passwordHash);
    string GenerateUniqueCode();
    string GenerateVerificationCode();
    string GenerateLinkingCode();
    bool IsValidEmail(string email);
    bool IsValidPassword(string password);
}
