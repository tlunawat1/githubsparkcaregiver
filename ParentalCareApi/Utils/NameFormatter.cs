using ParentalCareApi.Models;

namespace ParentalCareApi.Utils;

public static class NameFormatter
{
    public static string GetDisplayName(User? user)
    {
        if (user == null) return string.Empty;
        var lastName = user.LastName?.Trim();
        return string.IsNullOrWhiteSpace(lastName)
            ? user.FirstName
            : $"{user.FirstName} {lastName}";
    }
}
