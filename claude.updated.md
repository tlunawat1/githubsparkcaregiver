# ParentalCare Mobile Application (Updated)

A cross-platform care coordination and assistance mobile application for remote caregiving. This is NOT a surveillance tool - it is a care-focused platform for helping caregivers support dependents (elderly parents, family members) with reminders, task confirmation, and emergency assistance.

## Project Overview

**Domain**: AgeTech / Elder Care  
**Target Users**:
- Caregivers (manage reminders for dependents)
- Dependents (receive reminders and SOS support)

**Key Value Propositions**:
- Timely reminders for medicine, meals, and routines
- Confirmation of task completion
- Emergency escalation via SOS
- Peace of mind for caregivers, dignity for dependents

## Technology Stack

### Mobile App (Flutter)
- **Framework**: Flutter 3.10.7+ / Dart
- **State Management**: flutter_bloc (BLoC)
- **Routing**: go_router
- **Dependency Injection**: get_it
- **Local Database**: drift (SQLite)
- **Push Notifications**: firebase_messaging + flutter_local_notifications
- **Real-time Communication**: signalr_netcore
- **Audio**: record (voice notes), audioplayers
- **Storage**: flutter_secure_storage (tokens), shared_preferences (settings)

### Backend API (.NET 8)
- **Framework**: ASP.NET Core 8.0 Web API
- **Database**: SQL Server (Azure SQL Database)
- **ORM**: Entity Framework Core 8.0
- **Authentication**: JWT Bearer tokens (BCrypt password hashing)
- **Real-time**: SignalR (WebSockets)
- **Job Scheduling**: Hangfire (persistent background jobs)
- **Push Notifications**: Firebase Admin SDK
- **File Storage**: Azure Blob Storage
- **Timezone Handling**: NodaTime
- **API Documentation**: Swashbuckle (Swagger)

### Infrastructure
- **Hosting**: Azure App Service (Canada Central)
- **Database**: Azure SQL Database
- **Storage**: Azure Blob Storage
- **API URL**: `https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net`
- **Health Check**: `GET /health`
- **Hangfire Dashboard**: `/hangfire` (mapped in all envs; protect in production)
- **Swagger**: enabled only in Development (`/swagger`)

## Project Structure

```
MobileApp/
├── lib/                          # Flutter app source code
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # Main app widget
│   ├── core/
│   │   ├── constants/            # App config, colors, spacing, API constants
│   │   ├── di/                   # Dependency injection setup
│   │   ├── routing/              # GoRouter configuration
│   │   ├── services/             # FCM service, notification handler
│   │   └── theme/                # Material theme configuration
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local/            # Drift database
│   │   │   └── remote/           # API clients, SignalR service, sync manager
│   │   └── repositories/         # Data repositories
│   ├── features/
│   │   ├── auth/                 # Authentication screens & logic
│   │   ├── caregiver/            # Caregiver screens (dashboard, dependent management)
│   │   ├── dependent/            # Dependent screens (home, SOS, alerts)
│   │   ├── reminders/            # Reminder creation/editing screens
│   │   └── settings/             # Settings screens
│   └── shared/
│       ├── models/               # Shared data models
│       └── widgets/              # Reusable UI components
├── ParentalCareApi/              # .NET Backend API
│   ├── Program.cs                # API entry point & configuration
│   ├── Controllers/              # REST API endpoints
│   ├── Models/                   # Entity models
│   ├── DTOs/                     # Data transfer objects
│   ├── Services/                 # Business logic services
│   ├── Hubs/                     # SignalR hubs
│   ├── Data/                     # EF Core DbContext
│   └── appsettings.json          # Configuration
├── ios/                          # iOS native project
├── android/                      # Android native project
├── doc/                          # Documentation
└── pubspec.yaml                  # Flutter dependencies
```

## Data Models (Backend)

**User** (`Models/User.cs`)
- Id, Name, Email, PasswordHash
- Role: "caregiver" | "dependent"
- UniqueCode: 9-char alphanumeric for linking
- Timezone: IANA format (e.g., "America/New_York")
- DeviceToken (legacy) + multi-device tokens via UserDeviceTokens
- EmailVerified, VerificationCode

**CareRelationship** (`Models/CareRelationship.cs`)
- CaregiverId, DependentId
- Status: "pending" | "active" | "removed"
- LinkingCode: 5-digit verification
- InitiatedBy: who started the link

**Reminder** (`Models/Reminder.cs`)
- CreatorId, DependentId
- Title, Description, VoiceNoteUrl
- Hour, Minute (scheduled time in dependent timezone)
- RepeatPattern: "once" | "daily" | "weekly" | "specific_days"
- RepeatDays: JSON array like "[1,3,5]" for Mon/Wed/Fri
- Priority: "normal" | "high"
- StartDate, EndDate, IsActive

**ReminderInstance** (`Models/ReminderInstance.cs`)
- ReminderId, ScheduledTime (UTC)
- Status: "pending" | "completed" | "missed" | "snoozed"
- EscalationLevel: 0-2
- NotificationJobIds: Hangfire job IDs for cancellation

**SosEvent** (`Models/SosEvent.cs`)
- DependentId, Status: "triggered" | "cancelled" | "resolved"
- TriggeredAt, ResolvedAt, ResolvedBy

**NotificationLog** (`Models/NotificationLog.cs`)
- Tracks notification lifecycle, retry, status, and FCM message IDs

**UserDeviceToken** (`Models/UserDeviceToken.cs`)
- Multi-device token storage with platform, device name, and validity

## API Endpoints (Summary)

### Authentication (`/api/auth`)
- `POST /register`
- `POST /login`
- `POST /login-code`
- `POST /verify-email`
- `POST /refresh-token`
- `POST /send-verification-code`
- `POST /logout` (auth required)

### Users (`/api/users`)
- `GET /me` - Current user profile
- `PUT /me` - Update current user (name, phone, avatar, timezone)
- `GET /code/{code}` - Find user by unique code
- `GET /email/{email}` - Find user by email
- `GET /{id}` - Get user by ID
- `PUT /{id}` - Update linked user (caregiver only)
- `PUT /device-token` - Update legacy single device token

### Relationships (`/api/relationships`)
- `GET /` - List relationships
- `GET /pending` - Pending link requests
- `POST /` - Initiate link (code or email)
- `POST /{id}/verify` - Verify linking code
- `DELETE /{id}` - Remove relationship
- `GET /{id}/code` - Get linking code
- `POST /{id}/regenerate-code` - Regenerate linking code

### Reminders (`/api/reminders`)
- `GET /` - List reminders
- `GET /{id}` - Get reminder by ID
- `POST /` - Create reminder (caregiver only)
- `PUT /{id}` - Update reminder
- `DELETE /{id}` - Soft delete reminder (creator only)

### Reminder Instances (`/api/reminder-instances`)
- `GET /` - List instances (date/dependent filter)
- `GET /{id}` - Get instance by ID
- `POST /` - Create instance manually
- `PUT /{id}/complete`
- `PUT /{id}/snooze`
- `PUT /{id}/miss`
- `PUT /{id}/escalate`

### SOS (`/api/sos`)
- `GET /` - List SOS events
- `GET /active` - Active SOS (optional dependentId)
- `POST /` - Trigger SOS (dependent)
- `PUT /{id}/resolve`
- `PUT /{id}/cancel`

### Files (`/api/files`)
- `POST /voice-notes` - Upload voice note (audio only, 10MB limit)

### Device Tokens (`/api/device-tokens`)
- `POST /` - Register/update device token
- `GET /` - List active device tokens
- `DELETE /{id}` - Remove token
- `POST /invalidate` - Invalidate token by value
- `POST /logout` - Invalidate token on logout

## Real-time Communication (SignalR)

**Hub URL**: `/hubs/sync`

**Events to Clients**:
- `LinkRequestReceived`
- `LinkVerified`
- `LinkRemoved`
- `ReminderCreated/Updated/Deleted`
- `InstanceCreated`
- `InstanceStatusChanged`
- `SosTriggered/Resolved/Cancelled`
- `UserOnline`
- `Pong`

**Client Methods**:
- `SubscribeToDependent(dependentId)`
- `UnsubscribeFromDependent(dependentId)`
- `Ping()`
- `NotifyOnline()`

## Notification System

### Escalation Flow
1. Level 0 at scheduled time
2. Level 1 after `EscalationDelayMinutes`
3. Level 2 after another `EscalationDelayMinutes`
4. Auto-miss after `AutoMissDelayMinutes`

### Configuration (`appsettings.json`)
```json
"Notifications": {
  "EscalationDelayMinutes": 5,
  "AutoMissDelayMinutes": 30,
  "MissedGracePeriodMinutes": 5,
  "MaxRetryCount": 3,
  "DefaultTtlHours": 4
}
```

### Hangfire Jobs
- Notification jobs stored in `ReminderInstances.NotificationJobIds`
- Jobs cancelled when instance is completed
- Dashboard at `/hangfire`

## Key Screens (High-level)

### Caregiver Flow
1. CaregiverHomeScreen
2. DependentSelectorScreen (if multiple dependents)
3. DependentDashboardScreen
4. AddReminderScreen / EditReminderScreen
5. EmergencyContactsScreen

### Dependent Flow
1. DependentHomeScreen (reminders grid + SOS)
2. ReminderAlertScreen
3. SosScreen

### Shared
- WelcomeScreen, RoleSelectionScreen
- LoginScreen / RegistrationScreen / EmailVerificationScreen
- SettingsScreen (including notification sound, haptic feedback, reduce animations)

## Routing (GoRouter) - Primary

```dart
// Caregiver routes
/caregiver                         - CaregiverHomeScreen
/caregiver/dependents              - DependentSelectorScreen
/caregiver/dependent/:dependentId  - DependentDashboardScreen
/caregiver/dependent/:id/add-reminder
/caregiver/reminder/:id/edit
/caregiver/dependent/:id/emergency-contacts

// Dependent routes
/dependent                         - DependentHomeScreen
/dependent/reminder/:instanceId    - ReminderAlertScreen
/dependent/sos                     - SosScreen

// Auth routes
/login, /register, /email-verification

// Shared
/settings
```

## Dependency Injection Setup

Singletons registered in `core/di/injection.dart`:
- `AppDatabase`, `ApiClient`, `SignalRService`
- API services (`AuthApi`, `UserApi`, `ReminderApi`, etc.)
- Repositories and `SyncManager`

## Development Commands

### Flutter Mobile App
```bash
flutter run
flutter run -d 80F54299-B78B-4984-B72B-4BDF509AB26A  # iPhone 17 Pro
flutter run -d 7CA51281-D717-48D9-9E81-0348D3C11006  # iPhone 17
flutter build ios
flutter build apk
dart run build_runner build
dart run build_runner watch
```

### iOS Simulator App Management
```bash
xcrun simctl uninstall 80F54299-B78B-4984-B72B-4BDF509AB26A com.parentalcare.parentalCareApp
xcrun simctl uninstall 7CA51281-D717-48D9-9E81-0348D3C11006 com.parentalcare.parentalCareApp
xcrun simctl install 80F54299-B78B-4984-B72B-4BDF509AB26A /Users/pmagre/MobileApp/build/ios/iphonesimulator/Runner.app
xcrun simctl install 7CA51281-D717-48D9-9E81-0348D3C11006 /Users/pmagre/MobileApp/build/ios/iphonesimulator/Runner.app
xcrun simctl list devices
```

### .NET Backend - Local Development
```bash
/opt/homebrew/opt/dotnet@8/bin/dotnet build /Users/pmagre/MobileApp/ParentalCareApi
/opt/homebrew/opt/dotnet@8/bin/dotnet run --project /Users/pmagre/MobileApp/ParentalCareApi
/opt/homebrew/opt/dotnet@8/bin/dotnet publish /Users/pmagre/MobileApp/ParentalCareApi -c Release -o /Users/pmagre/MobileApp/ParentalCareApi/publish
```

### Azure Deployment
```bash
cd /Users/pmagre/MobileApp/ParentalCareApi/publish && zip -r ../deploy.zip .
az webapp deploy --resource-group RemoteCaregiverRG --name RemoteCareGiver-api --src-path /Users/pmagre/MobileApp/ParentalCareApi/deploy.zip --type zip
```

### Testing API
```bash
curl https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/health
open https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/swagger
open https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/hangfire
```

### Simulator Device IDs (Reference)
- **iPhone 17 Pro**: `80F54299-B78B-4984-B72B-4BDF509AB26A`
- **iPhone 17**: `7CA51281-D717-48D9-9E81-0348D3C11006`
- **App Bundle ID**: `com.parentalcare.parentalCareApp`

## Environment Configuration

### Flutter (`lib/core/constants/api_constants.dart`)
- `baseUrl` - API base URL
- `signalRHubUrl` - SignalR hub URL
- Environment enum for dev/staging/prod

### Backend (`appsettings.json`)
- `ConnectionStrings:DefaultConnection`
- `Jwt:Key`, `Jwt:Issuer`, `Jwt:Audience`, `Jwt:ExpirationInMinutes`, `Jwt:RefreshExpirationInDays`
- `Azure:BlobStorage:ConnectionString`, `Azure:BlobStorage:ContainerName`
- `Firebase:CredentialsPath`, `Firebase:CredentialsJson`, `Firebase:ProjectId`
- `Hangfire:DashboardPath`, `Hangfire:WorkerCount`
- `Notifications:*` (escalation, auto-miss, retry, TTL)

### Firebase Setup
- Place `google-services.json` in `android/app/`
- Place `GoogleService-Info.plist` in `ios/Runner/`
- Place `firebase-service-account.json` in `ParentalCareApi/`
- Or set `GOOGLE_APPLICATION_CREDENTIALS_JSON` env var

## Important Implementation Details

### Timezone Handling
- Reminders store Hour/Minute in dependent local timezone
- ReminderInstances store ScheduledTime in UTC
- UTC conversion via `NotificationJobService.ConvertToUtc()`
- Timezone updates trigger instance recalculation and job reschedule

### Voice Notes
- Recorded via `record` (Flutter)
- Uploaded via `POST /api/files/voice-notes`
- URL stored in `Reminder.VoiceNoteUrl`

### Link Request Flow
1. Caregiver searches dependent by UniqueCode or email
2. System creates pending CareRelationship with 5-digit LinkingCode
3. Dependent receives SignalR `LinkRequestReceived`
4. Dependent verifies link code
5. Relationship status becomes "active"

### Instance Generation
- Instances created when a reminder is saved (rolling window)
- `ReminderInstanceBackgroundService` generates future instances daily
- Each instance schedules Hangfire notification jobs

### App Resume Handling
- `WidgetsBindingObserver` monitors lifecycle
- On resume: verify SignalR connection and refresh data
- SignalR auto-restores subscriptions after reconnection

### UX and Accessibility Updates (Recent)
- Settings redesign with direct navigation and swipe-to-logout
- Reduce animations setting and staggered list animations
- Notification sound and haptic feedback toggles
- Modernized reminder and dashboard layouts

## Common Tasks

### Adding a New API Endpoint
1. Create DTO in `ParentalCareApi/DTOs/`
2. Add controller method
3. Create Dart API class in `lib/data/datasources/remote/`
4. Register in `core/di/injection.dart` if new service

### Adding a New Screen
1. Create screen widget in `lib/features/{feature}/presentation/screens/`
2. Add route in `lib/core/routing/app_router.dart`
3. Use `getIt<>` for dependency access

### Modifying Database Schema
- Backend: Add column in model, update `AppDbContext`, SQL update in `Program.cs`
- Mobile: Update `database.dart` tables, increment `schemaVersion`, add migration

## Debugging Tips

### API Issues
- Check Swagger at `/swagger` (dev only)
- Review Azure App Service logs
- Test with curl or Postman

### SignalR Issues
- Verify JWT token is being passed (access_token query for hubs)
- Check connection state and reconnection logs

### Push Notification Issues
- Verify device token registration
- Check `NotificationLogs` table
- Review Hangfire job status

## Security Considerations

- JWT tokens expire in 60 minutes; refresh tokens in 7 days
- Passwords hashed with BCrypt
- Tokens stored in Flutter Secure Storage
- API requires authorization for most endpoints
- Role-based access (caregiver vs dependent)
- Caregiver can only access linked dependents data

## Git Workflow

- Main branch: `main`
- Feature branches as needed
- Firebase config files excluded via `.gitignore`
