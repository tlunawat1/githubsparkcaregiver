# ParentalCare Mobile Application

A cross-platform care coordination and assistance mobile application for remote caregiving. This is NOT a surveillance tool - it's a care-focused platform for helping caregivers support their dependents (elderly parents, family members) with reminders, task confirmation, and emergency assistance.

## Project Overview

**Domain**: AgeTech / Elder Care
**Target Users**:
- Caregivers (family members who manage reminders for dependents)
- Dependents (elderly parents or assisted users who receive reminders)

**Key Value Propositions**:
- Timely reminders for medicine, meals, daily routines
- Confirmation of task completion
- Emergency escalation via SOS
- Peace of mind for caregivers, dignity for dependents

## Technology Stack

### Mobile App (Flutter)
- **Framework**: Flutter 3.10.7+ / Dart
- **State Management**: flutter_bloc (BLoC pattern)
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

## Project Structure

```
MobileApp/
├── lib/                          # Flutter app source code
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # Main app widget
│   ├── core/
│   │   ├── constants/            # App config, colors, spacing, API constants
│   │   ├── di/                   # Dependency injection setup (injection.dart)
│   │   ├── routing/              # GoRouter configuration (app_router.dart)
│   │   ├── services/             # FCM service, notification handler
│   │   └── theme/                # Material theme configuration
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local/            # Drift database (database.dart)
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

## Data Models

### Backend Models (C#)

**User** (`Models/User.cs`)
- Id, Name, Email, PasswordHash
- Role: "caregiver" | "dependent"
- UniqueCode: 9-char alphanumeric for linking
- Timezone: IANA format (e.g., "America/New_York")
- DeviceTokens: Push notification tokens
- EmailVerified, VerificationCode

**CareRelationship** (`Models/CareRelationship.cs`)
- CaregiverId, DependentId
- Status: "pending" | "active" | "removed"
- LinkingCode: 5-digit verification
- InitiatedBy: who started the link

**Reminder** (`Models/Reminder.cs`)
- CreatorId, DependentId
- Title, Description, VoiceNoteUrl
- Hour, Minute (scheduled time in dependent's timezone)
- RepeatPattern: "once" | "daily" | "weekly" | "specific_days"
- RepeatDays: JSON array like "[1,3,5]" for Mon/Wed/Fri
- Priority: "normal" | "high"
- StartDate, EndDate, IsActive

**ReminderInstance** (`Models/ReminderInstance.cs`)
- ReminderId, ScheduledTime (UTC)
- Status: "pending" | "completed" | "missed" | "snoozed"
- EscalationLevel: 0-2 (gentle → repeat → urgent)
- NotificationJobIds: Hangfire job IDs for cancellation

**SosEvent** (`Models/SosEvent.cs`)
- DependentId, Status: "triggered" | "cancelled" | "resolved"
- TriggeredAt, ResolvedAt, ResolvedBy

### Database Schema (Drift/SQLite - Mobile)

Same structure as backend with local tables:
- Users, CareRelationships, Reminders, ReminderInstances
- SosEvents, EmergencyContacts, AppSettings

## API Endpoints

### Authentication (`/api/auth`)
- `POST /register` - Register new user
- `POST /login` - Email/password login
- `POST /login-code` - Login with verification code
- `POST /verify-email` - Verify email with code
- `POST /refresh-token` - Refresh JWT token
- `POST /send-verification-code` - Request new code
- `POST /logout` - Logout (requires auth)

### Users (`/api/users`)
- `GET /me` - Get current user
- `GET /{id}` - Get user by ID
- `GET /search?code={code}` - Search user by unique code
- `PUT /me` - Update current user
- `PUT /me/timezone` - Update timezone

### Relationships (`/api/relationships`)
- `GET /` - Get all relationships
- `POST /initiate` - Start linking process
- `POST /verify` - Verify linking code
- `DELETE /{id}` - Remove relationship

### Reminders (`/api/reminders`)
- `GET /` - Get reminders (filtered by role/dependent)
- `GET /{id}` - Get single reminder
- `POST /` - Create reminder (caregiver only)
- `PUT /{id}` - Update reminder
- `DELETE /{id}` - Soft delete reminder

### Reminder Instances (`/api/reminderinstances`)
- `GET /` - Get instances (with date filter)
- `PUT /{id}/complete` - Mark as completed
- `PUT /{id}/snooze` - Snooze for specified time

### SOS (`/api/sos`)
- `GET /` - Get SOS events
- `POST /trigger` - Trigger SOS (dependent only)
- `POST /{id}/cancel` - Cancel SOS
- `POST /{id}/resolve` - Resolve SOS (caregiver)

### Files (`/api/files`)
- `POST /upload` - Upload voice note to Azure Blob

### Device Tokens (`/api/devicetokens`)
- `POST /` - Register FCM device token
- `DELETE /{id}` - Remove device token

## Real-time Communication (SignalR)

**Hub URL**: `/hubs/sync`

**Events Sent to Clients**:
- `LinkRequestReceived` - New link request
- `LinkVerified` - Link accepted
- `LinkRemoved` - Link removed
- `ReminderCreated/Updated/Deleted` - Reminder changes
- `InstanceCreated` - New reminder instance
- `InstanceStatusChanged` - Instance completed/missed/escalated
- `SosTriggered/Resolved/Cancelled` - SOS events
- `UserOnline` - Presence indicator
- `Pong` - Keep-alive response

**Client Methods**:
- `SubscribeToDependent(dependentId)` - Caregiver subscribes to updates
- `UnsubscribeFromDependent(dependentId)` - Stop receiving updates
- `Ping()` - Keep connection alive
- `NotifyOnline()` - Announce presence

## Notification System

### Escalation Flow
1. **Level 0 (Scheduled time)**: "Reminder: {title}"
2. **Level 1 (+5 min)**: "⚠️ Reminder: {title} (reminder)"
3. **Level 2 (+10 min)**: "🔴 Urgent: {title} (please respond)"
4. **Auto-miss (+30 min)**: Mark as missed, notify caregivers

### Configuration (`appsettings.json`)
```json
"Notifications": {
  "EscalationDelayMinutes": 5,
  "AutoMissDelayMinutes": 30,
  "MaxRetryCount": 3,
  "DefaultTtlHours": 4
}
```

### Hangfire Jobs
- Notification jobs stored in `NotificationJobIds` column
- Jobs can be cancelled when instance is completed
- Dashboard at `/hangfire`

## Key Screens

### Caregiver Flow
1. **CaregiverHomeScreen** - Entry point, redirects based on dependents
2. **DependentSelectorScreen** - Choose dependent (if multiple)
3. **DependentDashboardScreen** - View dependent's reminders/status
4. **AddReminderScreen** - Create new reminder
5. **EditReminderScreen** - Modify existing reminder
6. **EmergencyContactsScreen** - Manage emergency contacts

### Dependent Flow
1. **DependentHomeScreen** - Today's reminders grid + SOS button
2. **ReminderAlertScreen** - Full-screen reminder alert
3. **SosScreen** - SOS trigger and cancellation

### Shared
- **WelcomeScreen** - First launch
- **RoleSelectionScreen** - Choose caregiver/dependent
- **LoginScreen/RegistrationScreen** - Authentication
- **EmailVerificationScreen** - Verify email
- **SettingsScreen** - App settings

## Routing (GoRouter)

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
- `AppDatabase` - Local SQLite database
- `ApiClient` - HTTP client with token management
- `SignalRService` - Real-time communication
- `AuthApi`, `UserApi`, `ReminderApi`, etc. - API services
- `SyncManager` - Data synchronization
- Various repositories for local data access

## Development Commands

### Flutter Mobile App
```bash
# Run the app (will prompt for device selection)
flutter run

# Run on specific iOS simulator
flutter run -d 80F54299-B78B-4984-B72B-4BDF509AB26A  # iPhone 17 Pro
flutter run -d 7CA51281-D717-48D9-9E81-0348D3C11006  # iPhone 17

# Build for iOS
flutter build ios

# Build for Android
flutter build apk

# Generate drift database code
dart run build_runner build

# Watch for code generation changes
dart run build_runner watch
```

### iOS Simulator App Management
```bash
# Uninstall app from simulators
xcrun simctl uninstall 80F54299-B78B-4984-B72B-4BDF509AB26A com.parentalcare.parentalCareApp  # iPhone 17 Pro
xcrun simctl uninstall 7CA51281-D717-48D9-9E81-0348D3C11006 com.parentalcare.parentalCareApp  # iPhone 17

# Install app on simulator (after flutter build ios)
xcrun simctl install 80F54299-B78B-4984-B72B-4BDF509AB26A /Users/pmagre/MobileApp/build/ios/iphonesimulator/Runner.app
xcrun simctl install 7CA51281-D717-48D9-9E81-0348D3C11006 /Users/pmagre/MobileApp/build/ios/iphonesimulator/Runner.app

# List available simulators
xcrun simctl list devices
```

### .NET Backend - Local Development
```bash
# Build backend
/opt/homebrew/opt/dotnet@8/bin/dotnet build /Users/pmagre/MobileApp/ParentalCareApi

# Run locally
/opt/homebrew/opt/dotnet@8/bin/dotnet run --project /Users/pmagre/MobileApp/ParentalCareApi

# Publish for deployment
/opt/homebrew/opt/dotnet@8/bin/dotnet publish /Users/pmagre/MobileApp/ParentalCareApi -c Release -o /Users/pmagre/MobileApp/ParentalCareApi/publish
```

### Azure Deployment
```bash
# Create deployment zip
cd /Users/pmagre/MobileApp/ParentalCareApi/publish && zip -r ../deploy.zip .

# Deploy to Azure App Service
az webapp deploy --resource-group RemoteCaregiverRG --name RemoteCareGiver-api --src-path /Users/pmagre/MobileApp/ParentalCareApi/deploy.zip --type zip

# Full build and deploy sequence
/opt/homebrew/opt/dotnet@8/bin/dotnet publish /Users/pmagre/MobileApp/ParentalCareApi -c Release -o /Users/pmagre/MobileApp/ParentalCareApi/publish && \
cd /Users/pmagre/MobileApp/ParentalCareApi/publish && zip -r ../deploy.zip . && \
az webapp deploy --resource-group RemoteCaregiverRG --name RemoteCareGiver-api --src-path /Users/pmagre/MobileApp/ParentalCareApi/deploy.zip --type zip
```

### Testing API
```bash
# Health check
curl https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/health

# Swagger UI
open https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/swagger

# Hangfire Dashboard (job monitoring)
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
- `ConnectionStrings:DefaultConnection` - SQL Server connection
- `Jwt:Key/Issuer/Audience` - JWT configuration
- `Azure:BlobStorage` - Blob storage for voice notes
- `Firebase:CredentialsPath/ProjectId` - FCM configuration
- `Hangfire:DashboardPath/WorkerCount` - Job scheduler
- `Notifications:*` - Escalation timing

### Firebase Setup
- Place `google-services.json` in `android/app/`
- Place `GoogleService-Info.plist` in `ios/Runner/`
- Place `firebase-service-account.json` in `ParentalCareApi/`
- Or set `GOOGLE_APPLICATION_CREDENTIALS_JSON` env var

## Important Implementation Details

### Timezone Handling
- Reminders store Hour/Minute in dependent's local timezone
- ReminderInstances store ScheduledTime in UTC
- `NotificationJobService.ConvertToUtc()` handles conversion using NodaTime
- User's timezone stored in `Users.Timezone` (IANA format)

### Voice Notes
- Recorded using `record` package (Dart)
- Uploaded to Azure Blob Storage via `/api/files/upload`
- URL stored in `Reminder.VoiceNoteUrl`
- Auto-play on reminder alert screen

### Link Request Flow
1. Caregiver searches dependent by UniqueCode
2. System creates pending CareRelationship with 5-digit LinkingCode
3. Dependent receives SignalR `LinkRequestReceived` event
4. Dependent enters code to verify
5. On success, relationship status → "active"

### Instance Generation
- Created when reminder is saved (7-day rolling window)
- `ReminderInstanceBackgroundService` generates future instances daily
- Each instance gets Hangfire notification jobs scheduled

### App Resume Handling
- `WidgetsBindingObserver` monitors lifecycle
- On resume: verify SignalR connection, refresh data
- SignalR service auto-restores subscriptions after reconnection

## Common Tasks

### Adding a New API Endpoint
1. Create DTO in `ParentalCareApi/DTOs/`
2. Add controller method in appropriate controller
3. Create Dart API class in `lib/data/datasources/remote/`
4. Register in `injection.dart` if new service

### Adding a New Screen
1. Create screen widget in `lib/features/{feature}/presentation/screens/`
2. Add route in `lib/core/routing/app_router.dart`
3. Use `getIt<>` for dependency access

### Modifying Database Schema
- Backend: Add column in model, update `AppDbContext`, SQL update in `Program.cs`
- Mobile: Update `database.dart` tables, increment `schemaVersion`, add migration

### Testing Push Notifications
- Use Firebase Console to send test messages
- Check Hangfire dashboard for scheduled jobs
- Monitor logs for FCM message IDs

## Debugging Tips

### API Issues
- Check Swagger at `/swagger`
- Review logs in Azure Portal
- Test with curl or Postman

### SignalR Issues
- Enable debug logging: `debugLogDiagnostics: true` in GoRouter
- Check connection state: `_signalRService.currentState`
- Verify JWT token is being passed

### Push Notification Issues
- Verify FCM token registration
- Check `NotificationLogs` table in database
- Review Hangfire job status

## Security Considerations

- JWT tokens expire in 60 minutes, refresh tokens in 7 days
- Passwords hashed with BCrypt
- Tokens stored in Flutter Secure Storage
- API requires authorization for most endpoints
- Role-based access (caregiver vs dependent)
- Caregiver can only access linked dependents' data

## Git Workflow

- Main branch: `main`
- Feature branches as needed
- Firebase config files excluded via `.gitignore`
