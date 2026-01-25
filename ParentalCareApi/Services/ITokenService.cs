using ParentalCareApi.Models;

namespace ParentalCareApi.Services;

public interface ITokenService
{
    string GenerateAccessToken(User user);
    string GenerateRefreshToken();
    bool ValidateRefreshToken(User user, string refreshToken);
}
