namespace ParentalCareApi.Services;

public class EmailVerificationOptions
{
    public const string SectionName = "EmailVerification";

    public string SenderAddress { get; set; } =
        "DoNotReply@c957d94d-4ee4-4362-99f7-463281b1201d.azurecomm.net";

    public int VerificationCodeExpiryMinutes { get; set; } = 10;

    public int ResendCooldownSeconds { get; set; } = 60;
}
