using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using ParentalCareApi.Data;
using ParentalCareApi.Hubs;
using ParentalCareApi.Services;
using Hangfire;
using Hangfire.SqlServer;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Parental Care API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Database
var defaultConnectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(defaultConnectionString))
{
    throw new InvalidOperationException("Default connection string not configured. Set ConnectionStrings__DefaultConnection.");
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(defaultConnectionString));

// JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey))
{
    throw new InvalidOperationException("JWT Key not configured. Set Jwt__Key.");
}
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "ParentalCareApi";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "ParentalCareApp";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };

    // Configure SignalR authentication
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();

// SignalR
builder.Services.AddSignalR();

// Custom Services
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.Configure<EmailVerificationOptions>(
    builder.Configuration.GetSection(EmailVerificationOptions.SectionName));
builder.Services.AddScoped<IEmailService, AzureCommunicationEmailService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddSingleton<IBlobStorageService, BlobStorageService>();

// Background Services
builder.Services.AddHostedService<ReminderInstanceBackgroundService>();

// Hangfire for persistent job scheduling
var connectionString = defaultConnectionString;
builder.Services.AddHangfire(config => config
    .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
    .UseSimpleAssemblyNameTypeSerializer()
    .UseRecommendedSerializerSettings()
    .UseSqlServerStorage(connectionString, new SqlServerStorageOptions
    {
        CommandBatchMaxTimeout = TimeSpan.FromMinutes(5),
        SlidingInvisibilityTimeout = TimeSpan.FromMinutes(5),
        QueuePollInterval = TimeSpan.Zero,
        UseRecommendedIsolationLevel = true,
        DisableGlobalLocks = true,
        PrepareSchemaIfNecessary = true,
        SchemaName = "HangFire"
    }));

var workerCount = builder.Configuration.GetValue<int>("Hangfire:WorkerCount", 5);
builder.Services.AddHangfireServer(options =>
{
    options.WorkerCount = workerCount;
});

// Firebase Admin SDK - supports both file and environment variable
var firebaseCredPath = builder.Configuration["Firebase:CredentialsPath"];
var firebaseCredJson = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS_JSON")
                       ?? builder.Configuration["Firebase:CredentialsJson"];
var firebaseProjectId = builder.Configuration["Firebase:ProjectId"];

if (!string.IsNullOrEmpty(firebaseCredJson))
{
    // Load from JSON string (environment variable or config)
    FirebaseApp.Create(new AppOptions
    {
        Credential = GoogleCredential.FromJson(firebaseCredJson),
        ProjectId = firebaseProjectId
    });
    Console.WriteLine("Firebase initialized from credentials JSON");
}
else if (!string.IsNullOrEmpty(firebaseCredPath) && File.Exists(firebaseCredPath))
{
    // Load from file
    FirebaseApp.Create(new AppOptions
    {
        Credential = GoogleCredential.FromFile(firebaseCredPath),
        ProjectId = firebaseProjectId
    });
    Console.WriteLine("Firebase initialized from credentials file");
}
else
{
    // Log warning but don't fail - allows running without Firebase for development
    Console.WriteLine("Warning: Firebase credentials not found. Push notifications will be logged only.");
    Console.WriteLine("Set GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable or Firebase:CredentialsPath config");
}

// Notification services
builder.Services.AddScoped<INotificationJobService, NotificationJobService>();

// CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });

    options.AddPolicy("AllowSignalR", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<SyncHub>("/hubs/sync");

// Hangfire Dashboard (admin access only in production)
var hangfirePath = builder.Configuration["Hangfire:DashboardPath"] ?? "/hangfire";
app.MapHangfireDashboard(hangfirePath, new DashboardOptions
{
    DashboardTitle = "Parental Care - Job Dashboard",
    // In production, add authorization filter
    // Authorization = new[] { new HangfireAuthorizationFilter() }
});

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));

// Ensure database tables exist on startup and apply schema updates
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();

    // Apply schema updates for new columns/tables (EnsureCreated doesn't update existing schema)
    try
    {
        // Add Timezone column to Users if it doesn't exist
        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'Users') AND name = 'Timezone')
            BEGIN
                ALTER TABLE Users ADD Timezone NVARCHAR(50) NOT NULL DEFAULT 'UTC'
            END");

        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'Users') AND name = 'VerificationCodeSentAt')
            BEGIN
                ALTER TABLE Users ADD VerificationCodeSentAt DATETIME2 NULL
            END");

        // Add NotificationJobIds column to ReminderInstances if it doesn't exist
        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ReminderInstances') AND name = 'NotificationJobIds')
            BEGIN
                ALTER TABLE ReminderInstances ADD NotificationJobIds NVARCHAR(MAX) NULL
            END");

        // Add EscalationLevel column to ReminderInstances if it doesn't exist
        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ReminderInstances') AND name = 'EscalationLevel')
            BEGIN
                ALTER TABLE ReminderInstances ADD EscalationLevel INT NOT NULL DEFAULT 0
            END");

        // Create UserDeviceTokens table if it doesn't exist
        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserDeviceTokens')
            BEGIN
                CREATE TABLE UserDeviceTokens (
                    Id NVARCHAR(36) NOT NULL PRIMARY KEY,
                    UserId NVARCHAR(36) NOT NULL,
                    Token NVARCHAR(500) NOT NULL,
                    Platform NVARCHAR(20) NOT NULL,
                    DeviceName NVARCHAR(100) NULL,
                    AppVersion NVARCHAR(20) NULL,
                    IsValid BIT NOT NULL DEFAULT 1,
                    LastUsedAt DATETIME2 NULL,
                    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
                );
                CREATE INDEX IX_UserDeviceTokens_UserId ON UserDeviceTokens(UserId);
                CREATE INDEX IX_UserDeviceTokens_Token ON UserDeviceTokens(Token);
            END");

        // Create NotificationLogs table if it doesn't exist
        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'NotificationLogs')
            BEGIN
                CREATE TABLE NotificationLogs (
                    Id NVARCHAR(36) NOT NULL PRIMARY KEY,
                    UserId NVARCHAR(36) NOT NULL,
                    DeviceTokenId NVARCHAR(36) NULL,
                    Type NVARCHAR(50) NOT NULL,
                    ReferenceId NVARCHAR(36) NULL,
                    Title NVARCHAR(200) NULL,
                    Body NVARCHAR(500) NULL,
                    Payload NVARCHAR(MAX) NULL,
                    ScheduledAt DATETIME2 NULL,
                    SentAt DATETIME2 NULL,
                    DeliveredAt DATETIME2 NULL,
                    ReadAt DATETIME2 NULL,
                    Status NVARCHAR(20) NOT NULL,
                    ErrorMessage NVARCHAR(500) NULL,
                    RetryCount INT NOT NULL DEFAULT 0,
                    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
                );
                CREATE INDEX IX_NotificationLogs_UserId ON NotificationLogs(UserId);
                CREATE INDEX IX_NotificationLogs_Status ON NotificationLogs(Status);
            END");

        // Add missing NotificationLogs columns if table already exists
        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'NotificationLogs') AND name = 'FcmMessageId')
            BEGIN
                ALTER TABLE NotificationLogs ADD FcmMessageId NVARCHAR(100) NULL
            END");

        db.Database.ExecuteSqlRaw(@"
            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'NotificationLogs') AND name = 'EscalationLevel')
            BEGIN
                ALTER TABLE NotificationLogs ADD EscalationLevel INT NOT NULL DEFAULT 0
            END");

        Console.WriteLine("Database schema updates applied successfully");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: Could not apply schema updates: {ex.Message}");
    }
}

app.Run();
