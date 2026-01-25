using System.Text.RegularExpressions;

namespace ParentalCareApi.Services;

public class AuthService : IAuthService
{
    // Characters that look similar are excluded (0, O, 1, I, L)
    private const string UniqueCodeChars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static readonly Random _random = new();

    public string HashPassword(string password)
    {
        return BCrypt.Net.BCrypt.HashPassword(password, BCrypt.Net.BCrypt.GenerateSalt(12));
    }

    public bool VerifyPassword(string password, string passwordHash)
    {
        try
        {
            return BCrypt.Net.BCrypt.Verify(password, passwordHash);
        }
        catch
        {
            return false;
        }
    }

    public string GenerateUniqueCode()
    {
        var code = new char[9];
        for (int i = 0; i < 9; i++)
        {
            code[i] = UniqueCodeChars[_random.Next(UniqueCodeChars.Length)];
        }
        return new string(code);
    }

    public string GenerateVerificationCode()
    {
        return _random.Next(100000, 999999).ToString();
    }

    public string GenerateLinkingCode()
    {
        return _random.Next(10000, 99999).ToString();
    }

    public bool IsValidEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return false;

        var emailRegex = new Regex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.IgnoreCase);
        return emailRegex.IsMatch(email);
    }

    public bool IsValidPassword(string password)
    {
        return !string.IsNullOrWhiteSpace(password) && password.Length >= 6;
    }
}
