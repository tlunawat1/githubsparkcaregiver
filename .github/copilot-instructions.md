# GitHub Copilot Instructions

## Project Overview

**ParentalCare / CareNest** is a cross-platform care coordination mobile application for remote caregiving. This is NOT a surveillance tool — it's a care-focused platform helping caregivers support their dependents (elderly parents, family members) with reminders, task confirmation, and emergency assistance.

**Domain**: AgeTech / Elder Care  
**Target Users**:
- Caregivers: family members who create and manage reminders for dependents
- Dependents: elderly parents or assisted users who receive reminders and can trigger SOS

## Technology Stack

### Mobile App (Flutter/Dart)
- **Framework**: Flutter 3.10.7+ / Dart
- **State Management**: `flutter_bloc` (BLoC pattern)
- **Routing**: `go_router`
- **Dependency Injection**: `get_it`
- **Local Database**: `drift` (SQLite with code generation)
- **Push Notifications**: `firebase_messaging` + `flutter_local_notifications`
- **Real-time**: `signalr_netcore` (WebSockets)
- **Audio**: `record` (voice notes), `audioplayers`
- **Storage**: `flutter_secure_storage` (tokens), `shared_preferences` (settings)

### Backend API (.NET 8 / C#)
- **Framework**: ASP.NET Core 8.0 Web API
- **Database**: SQL Server via Entity Framework Core 8.0
- **Authentication**: JWT Bearer tokens (BCrypt password hashing)
- **Real-time**: SignalR (WebSockets)
- **Job Scheduling**: Hangfire (persistent background jobs)
- **Push Notifications**: Firebase Admin SDK
- **File Storage**: Azure Blob Storage
- **Timezone Handling**: NodaTime
- **API Docs**: Swashbuckle (Swagger)

## Project Structure

```
lib/
├── main.dart                     # App entry point (Firebase, DI, orientation)
├── app.dart                      # Root widget, lifecycle observer, SignalR/FCM init
├── core/
│   ├── constants/                # API URLs, colors, spacing
│   ├── di/injection.dart         # GetIt dependency registration
│   ├── routing/app_router.dart   # GoRouter config + route constants
│   ├── services/                 # FCM, notification handler, alarm service
│   ├── theme/app_theme.dart      # Material light/dark themes
│   └── utils/                   # Feedback, formatting helpers
├── data/
│   ├── datasources/
│   │   ├── local/database.dart   # Drift SQLite schema + DAOs
│   │   └── remote/               # ApiClient, SignalRService, per-resource APIs
│   └── repositories/             # Thin wrappers over local/remote sources
├── features/
│   ├── auth/                     # Login, register, email verification screens
│   ├── caregiver/                # Dashboard, dependent selector, reminder management
│   ├── dependent/                # Home grid, SOS screen, reminder alert
│   ├── reminders/                # Add/edit reminder screens
│   └── settings/                 # Settings, edit profile screens
└── shared/
    ├── models/                   # Shared Dart data classes
    └── widgets/                  # Reusable UI components (barrel file: widgets.dart)

ParentalCareApi/
├── Program.cs                    # App config, EF migrations, Hangfire setup
├── Controllers/                  # REST endpoints (Auth, Users, Reminders, SOS, etc.)
├── Models/                       # EF entity classes
├── DTOs/                         # Request/response transfer objects
├── Services/                     # Business logic (notifications, instance generation)
├── Hubs/SyncHub.cs               # SignalR hub
└── Data/AppDbContext.cs          # EF Core DbContext
```

## Coding Conventions

### Flutter/Dart
- Use `getIt<T>()` to resolve dependencies — never instantiate services directly
- All screens live in `lib/features/{feature}/presentation/screens/`
- Reusable widgets go in `lib/shared/widgets/` and are exported via `widgets.dart`
- New routes must be added to `AppRoutes` constants and `AppRouter` configuration
- Use `context.go()` / `context.push()` from GoRouter for navigation
- Database schema changes: update `database.dart`, increment `schemaVersion`, add migration
- After any `database.dart` change, run `dart run build_runner build` to regenerate `.g.dart` files

### Backend (C#)
- New endpoints: add DTO → controller method → register any new service in `Program.cs`
- Always check user role (`caregiver` / `dependent`) and relationship ownership in controllers
- Reminder scheduling time is stored in the **dependent's local timezone** (Hour + Minute fields)
- `ReminderInstance.ScheduledTime` is always **UTC**
- Use NodaTime for all timezone conversions

## Key Flows

### Linking Caregiver ↔ Dependent
1. Caregiver searches dependent by 9-char `UniqueCode`
2. Backend creates a pending `CareRelationship` with a 5-digit `LinkingCode`
3. Dependent receives `LinkRequestReceived` via SignalR
4. Dependent enters code → relationship becomes `active`

### Reminder Notification Escalation
| Level | Trigger | Message |
|-------|---------|---------|
| 0 | Scheduled time | "Reminder: {title}" |
| 1 | +5 min | "⚠️ Reminder: {title} (reminder)" |
| 2 | +10 min | "🔴 Urgent: {title} (please respond)" |
| auto-miss | +30 min | Mark missed, notify caregivers |

### App Lifecycle (app.dart)
- `WidgetsBindingObserver` monitors foreground/background transitions
- On resume: refresh JWT token → update SignalR token → reconnect if needed
- Background init (non-blocking): token refresh → SignalR connect → FCM register

## API Base URL

```
https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net
```

## Common Development Tasks

### Adding a Screen
1. Create widget in `lib/features/{feature}/presentation/screens/`
2. Add route constant to `AppRoutes` in `app_router.dart`
3. Add `GoRoute` entry in `AppRouter._buildRouter()`

### Adding an API Endpoint
1. Create/update DTO in `ParentalCareApi/DTOs/`
2. Add controller method with `[Authorize]` + role check
3. Create/update Dart API class in `lib/data/datasources/remote/`
4. Register new service in `injection.dart` if needed

### Build Commands
```bash
# Flutter: get dependencies
flutter pub get

# Flutter: regenerate drift/injectable code
dart run build_runner build --delete-conflicting-outputs

# Flutter: run tests
flutter test

# .NET: build backend
dotnet build ParentalCareApi

# .NET: run backend locally
dotnet run --project ParentalCareApi
```

## Security Notes
- JWT access tokens expire in 60 minutes; refresh tokens in 7 days
- Tokens stored in `flutter_secure_storage` (OS keychain)
- BCrypt used for password hashing — never store plain-text passwords
- Role-based access enforced server-side; caregivers can only access their linked dependents
- Firebase credential files (`google-services.json`, `GoogleService-Info.plist`, `firebase-service-account.json`) are gitignored — never commit them
