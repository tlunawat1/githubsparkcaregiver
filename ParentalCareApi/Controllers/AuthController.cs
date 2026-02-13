using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using ParentalCareApi.Data;
using ParentalCareApi.DTOs;
using ParentalCareApi.Models;
using ParentalCareApi.Services;

namespace ParentalCareApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ITokenService _tokenService;
    private readonly IAuthService _authService;
    private readonly IEmailService _emailService;
    private readonly EmailVerificationOptions _emailVerificationOptions;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        AppDbContext context,
        ITokenService tokenService,
        IAuthService authService,
        IEmailService emailService,
        IOptions<EmailVerificationOptions> emailVerificationOptions,
        IConfiguration configuration,
        ILogger<AuthController> logger)
    {
        _context = context;
        _tokenService = tokenService;
        _authService = authService;
        _emailService = emailService;
        _emailVerificationOptions = emailVerificationOptions.Value;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost("register")]
    public async Task<ActionResult<RegisterResponse>> Register([FromBody] RegisterRequest request)
    {
        if (!_authService.IsValidEmail(request.Email))
            return BadRequest(new { message = "Invalid email format" });

        if (!_authService.IsValidPassword(request.Password))
            return BadRequest(new { message = "Password must be at least 6 characters" });

        if (request.Role != "caregiver" && request.Role != "dependent")
            return BadRequest(new { message = "Role must be 'caregiver' or 'dependent'" });

        // Check if email already exists
        var existingUser = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
        if (existingUser != null)
            return Conflict(new { message = "Email already registered" });

        // Generate unique code
        string uniqueCode;
        do
        {
            uniqueCode = _authService.GenerateUniqueCode();
        } while (await _context.Users.AnyAsync(u => u.UniqueCode == uniqueCode));

        var user = new User
        {
            Id = Guid.NewGuid().ToString(),
            Name = request.Name,
            Email = request.Email.ToLowerInvariant(),
            PasswordHash = _authService.HashPassword(request.Password),
            Role = request.Role,
            PhoneNumber = request.PhoneNumber,
            UniqueCode = uniqueCode,
            Timezone = request.Timezone ?? "UTC",
            EmailVerified = false,
            VerificationCode = _authService.GenerateVerificationCode(),
            VerificationCodeExpiry = DateTime.UtcNow.AddMinutes(_emailVerificationOptions.VerificationCodeExpiryMinutes),
            VerificationCodeSentAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        _logger.LogInformation("User registered: {Email}, Code: {UniqueCode}", user.Email, user.UniqueCode);

        var registrationMessage = "Registration successful. Please verify your email.";
        try
        {
            await _emailService.SendVerificationCodeAsync(user.Email, user.VerificationCode!);
        }
        catch (Exception ex)
        {
            // Keep registration fast and successful even if email provider is slow/unavailable.
            _logger.LogWarning(ex, "User created but failed to send verification code for {Email}", user.Email);
            registrationMessage = "Registration successful. We could not send a verification code now. Please tap resend code.";
        }

        return CreatedAtAction(nameof(Register), new RegisterResponse(
            user.Id,
            user.Name,
            user.Email,
            user.Role,
            user.UniqueCode,
            user.EmailVerified,
            registrationMessage
        ));
    }

    [HttpPost("login")]
    public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.Email == request.Email.ToLowerInvariant());

        if (user == null)
            return Unauthorized(new { message = "Invalid email or password" });

        if (!_authService.VerifyPassword(request.Password, user.PasswordHash))
            return Unauthorized(new { message = "Invalid email or password" });

        if (!user.EmailVerified)
            return Unauthorized(new { message = "Please verify your email first", requiresVerification = true, userId = user.Id });

        return await GenerateLoginResponse(user);
    }

    [HttpPost("login-code")]
    public async Task<ActionResult<LoginResponse>> LoginWithCode([FromBody] LoginCodeRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.Email == request.Email.ToLowerInvariant());

        if (user == null)
            return Unauthorized(new { message = "Invalid email or code" });

        var isValidCode = IsVerificationCodeValid(user, request.Code, out var isExpired);

        if (!isValidCode)
        {
            return Unauthorized(new
            {
                message = isExpired ? "Verification code has expired" : "Invalid verification code"
            });
        }

        // Auto-verify email if logging in with code
        if (!user.EmailVerified)
        {
            user.EmailVerified = true;
            user.UpdatedAt = DateTime.UtcNow;
        }

        user.VerificationCode = null;
        user.VerificationCodeExpiry = null;
        user.VerificationCodeSentAt = null;
        user.UpdatedAt = DateTime.UtcNow;

        return await GenerateLoginResponse(user);
    }

    [HttpPost("verify-email")]
    public async Task<ActionResult<VerifyEmailResponse>> VerifyEmail([FromBody] VerifyEmailRequest request)
    {
        var user = await _context.Users.FindAsync(request.UserId);

        if (user == null)
            return NotFound(new { message = "User not found" });

        if (user.EmailVerified)
            return Ok(new VerifyEmailResponse(true, "Email already verified", user.UniqueCode));

        var isValidCode = IsVerificationCodeValid(user, request.Code, out var isExpired);

        if (!isValidCode)
        {
            return BadRequest(new VerifyEmailResponse(
                false,
                isExpired ? "Verification code has expired" : "Invalid verification code"));
        }

        user.EmailVerified = true;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new VerifyEmailResponse(true, "Email verified successfully", user.UniqueCode));
    }

    [HttpPost("refresh-token")]
    public async Task<ActionResult<LoginResponse>> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.RefreshToken == request.RefreshToken);

        if (user == null || !_tokenService.ValidateRefreshToken(user, request.RefreshToken))
            return Unauthorized(new { message = "Invalid or expired refresh token" });

        return await GenerateLoginResponse(user);
    }

    [HttpPost("send-verification-code")]
    public async Task<ActionResult<SendVerificationCodeResponse>> SendVerificationCode(
        [FromBody] SendVerificationCodeRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(
            u => u.Email == request.Email.ToLowerInvariant());

        if (user == null)
            return Ok(new SendVerificationCodeResponse(true, "If this email exists, a code will be sent"));

        if (TryGetRetryAfterSeconds(user, out var retryAfterSeconds))
        {
            return StatusCode(StatusCodes.Status429TooManyRequests,
                new SendVerificationCodeResponse(
                    false,
                    "Please wait before requesting another code",
                    retryAfterSeconds));
        }

        SetNewVerificationCode(user);
        await _context.SaveChangesAsync();

        try
        {
            await _emailService.SendVerificationCodeAsync(user.Email, user.VerificationCode!);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send verification code to {Email}", user.Email);
            return StatusCode(500, new SendVerificationCodeResponse(false, "Failed to send verification code"));
        }

        return Ok(new SendVerificationCodeResponse(
            true,
            "Verification code sent",
            null,
            user.VerificationCodeExpiry));
    }

    [HttpPost("resend-verification")]
    public async Task<ActionResult<SendVerificationCodeResponse>> ResendVerificationCode(
        [FromBody] ResendVerificationRequest request)
    {
        var user = await _context.Users.FindAsync(request.UserId);

        if (user == null)
            return NotFound(new SendVerificationCodeResponse(false, "User not found"));

        if (user.EmailVerified)
            return BadRequest(new SendVerificationCodeResponse(false, "Email already verified"));

        if (TryGetRetryAfterSeconds(user, out var retryAfterSeconds))
        {
            return StatusCode(StatusCodes.Status429TooManyRequests,
                new SendVerificationCodeResponse(
                    false,
                    "Please wait before requesting another code",
                    retryAfterSeconds));
        }

        SetNewVerificationCode(user);
        await _context.SaveChangesAsync();

        try
        {
            await _emailService.SendVerificationCodeAsync(user.Email, user.VerificationCode!);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to resend verification code to {Email}", user.Email);
            return StatusCode(500, new SendVerificationCodeResponse(false, "Failed to send verification code"));
        }

        return Ok(new SendVerificationCodeResponse(
            true,
            "Verification code sent",
            null,
            user.VerificationCodeExpiry));
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (userId == null)
            return Unauthorized();

        var user = await _context.Users.FindAsync(userId);
        if (user != null)
        {
            user.RefreshToken = null;
            user.RefreshTokenExpiry = null;
            await _context.SaveChangesAsync();
        }

        return Ok(new { message = "Logged out successfully" });
    }

    private async Task<ActionResult<LoginResponse>> GenerateLoginResponse(User user)
    {
        var accessToken = _tokenService.GenerateAccessToken(user);
        var refreshToken = _tokenService.GenerateRefreshToken();
        var refreshExpirationDays = int.Parse(_configuration["Jwt:RefreshExpirationInDays"] ?? "7");

        user.RefreshToken = refreshToken;
        user.RefreshTokenExpiry = DateTime.UtcNow.AddDays(refreshExpirationDays);
        user.LastLoginAt = DateTime.UtcNow;
        user.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var expirationMinutes = int.Parse(_configuration["Jwt:ExpirationInMinutes"] ?? "60");

        return Ok(new LoginResponse(
            accessToken,
            refreshToken,
            DateTime.UtcNow.AddMinutes(expirationMinutes),
            new UserDto(
                user.Id,
                user.Name,
                user.Email,
                user.Role,
                user.PhoneNumber,
                user.UniqueCode,
                user.AvatarUrl,
                user.EmailVerified,
                user.Timezone,
                user.CreatedAt,
                user.LastLoginAt
            )
        ));
    }

    private bool IsVerificationCodeValid(User user, string inputCode, out bool isExpired)
    {
        isExpired = false;
        if (string.IsNullOrWhiteSpace(user.VerificationCode) || user.VerificationCodeExpiry == null)
            return false;

        if (user.VerificationCodeExpiry.Value <= DateTime.UtcNow)
        {
            isExpired = true;
            return false;
        }

        return string.Equals(user.VerificationCode, inputCode, StringComparison.Ordinal);
    }

    private bool TryGetRetryAfterSeconds(User user, out int retryAfterSeconds)
    {
        retryAfterSeconds = 0;
        if (!user.VerificationCodeSentAt.HasValue)
            return false;

        var elapsed = DateTime.UtcNow - user.VerificationCodeSentAt.Value;
        var cooldown = TimeSpan.FromSeconds(_emailVerificationOptions.ResendCooldownSeconds);
        if (elapsed >= cooldown)
            return false;

        retryAfterSeconds = (int)Math.Ceiling((cooldown - elapsed).TotalSeconds);
        return true;
    }

    private void SetNewVerificationCode(User user)
    {
        user.VerificationCode = _authService.GenerateVerificationCode();
        user.VerificationCodeExpiry = DateTime.UtcNow.AddMinutes(_emailVerificationOptions.VerificationCodeExpiryMinutes);
        user.VerificationCodeSentAt = DateTime.UtcNow;
        user.UpdatedAt = DateTime.UtcNow;
    }
}
