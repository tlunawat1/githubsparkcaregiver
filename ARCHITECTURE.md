# Parental Care App - Architecture & Technical Documentation

## Overview

Parental Care is a mobile application designed to help caregivers manage reminders and provide emergency support for their dependents (elderly family members, patients, etc.). The system consists of a Flutter mobile app and a .NET 8 backend API.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Technology Stack](#2-technology-stack)
3. [Mobile App Architecture](#3-mobile-app-architecture)
4. [Data Layer](#4-data-layer)
5. [Features](#5-features)
6. [Backend API](#6-backend-api)
7. [Real-time Communication](#7-real-time-communication)
8. [Authentication & Security](#8-authentication--security)
9. [Key Workflows](#9-key-workflows)
10. [Configuration](#10-configuration)
11. [Dependencies](#11-dependencies)
12. [Known Limitations & TODOs](#12-known-limitations--todos)

---

## 1. Project Structure

### Root Directory Layout
```
/Users/pmagre/MobileApp/
├── lib/                          # Flutter mobile app source code
├── ParentalCareApi/              # .NET 8 backend API
├── android/                      # Android platform configuration
├── ios/                          # iOS platform configuration
├── assets/                       # Images and audio resources
├── pubspec.yaml                  # Flutter dependencies
└── ARCHITECTURE.md               # This document
```

### Flutter App Structure
```
lib/
├── main.dart                     # Entry point
├── app.dart                      # App widget + initialization
├── core/                         # Core/Infrastructure layer
│   ├── constants/                # App constants, colors, spacing
│   ├── di/                       # Dependency injection (GetIt)
│   ├── routing/                  # GoRouter navigation
│   └── theme/                    # Material Design theming
├── data/                         # Data layer
│   ├── datasources/
│   │   ├── local/                # Drift SQLite database
│   │   └── remote/               # REST APIs & SignalR
│   ├── models/                   # Data models (DTOs)
│   └── repositories/             # Repository implementations
├── features/                     # Feature modules
│   ├── auth/                     # Authentication
│   ├── caregiver/                # Caregiver screens
│   ├── dependent/                # Dependent screens
│   ├── reminders/                # Reminder management
│   ├── sos/                      # SOS emergency system
│   └── settings/                 # App settings
└── shared/                       # Shared components
    ├── widgets/                  # Reusable UI widgets
    ├── models/                   # Shared domain models
    └── utils/                    # Helper utilities
```

### Backend API Structure
```
ParentalCareApi/
├── Program.cs                    # ASP.NET Core startup
├── Controllers/                  # API endpoints
│   ├── AuthController.cs         # Authentication
│   ├── UsersController.cs        # User management
│   ├── RemindersController.cs    # Reminder CRUD
│   ├── ReminderInstancesController.cs  # Instance management
│   ├── RelationshipsController.cs      # Care relationships
│   ├── SosController.cs          # SOS events
│   └── FilesController.cs        # File uploads
├── Models/                       # Entity Framework models
├── DTOs/                         # Data transfer objects
├── Data/                         # DbContext
├── Services/                     # Business logic services
├── Hubs/                         # SignalR hub
└── Scripts/                      # Database scripts
```

---

## 2. Technology Stack

### Mobile App (Flutter)
| Category | Technology | Version |
|----------|------------|---------|
| Framework | Flutter | 3.10.7+ |
| Language | Dart | 3.x |
| State Management | flutter_bloc + Streams | 9.1.1 |
| Navigation | GoRouter | 15.1.2 |
| Local Database | Drift (SQLite) | 2.24.0 |
| HTTP Client | http | 1.2.0 |
| Real-time | signalr_netcore | 1.3.7 |
| DI | GetIt + Injectable | 8.0.3 |
| Secure Storage | flutter_secure_storage | 9.0.0 |
| Notifications | flutter_local_notifications | 18.0.1 |
| Audio | record + audioplayers | 6.1.2 / 6.4.0 |

### Backend API (.NET 8)
| Category | Technology |
|----------|------------|
| Framework | ASP.NET Core 8 |
| Database | SQL Server (Entity Framework Core) |
| Real-time | SignalR |
| Authentication | JWT Bearer Tokens |
| File Storage | Azure Blob Storage |
| API Documentation | Swagger/OpenAPI |

---

## 3. Mobile App Architecture

### Architecture Pattern: Clean Architecture with Repository Pattern

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                          │
│  (Screens, Widgets, State Management)               │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│               Repository Layer                       │
│  (UserRepository, ReminderRepository, etc.)         │
└─────────────────────┬───────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
┌───────▼───────┐           ┌───────▼───────┐
│ Local Database │           │  Remote APIs   │
│   (Drift)      │◄─────────►│  (HTTP/WS)    │
└───────────────┘   Sync     └───────────────┘
```

### Dependency Injection

**File**: `lib/core/di/injection.dart`

```dart
// Singleton registrations
getIt.registerSingleton<AppDatabase>(AppDatabase());
getIt.registerSingleton<ApiClient>(ApiClient());
getIt.registerSingleton<SignalRService>(SignalRService());

// Lazy singleton registrations (created on first use)
getIt.registerLazySingleton<UserApi>(() => UserApi(getIt<ApiClient>()));
getIt.registerLazySingleton<ReminderApi>(() => ReminderApi(getIt<ApiClient>()));
getIt.registerLazySingleton<UserRepository>(() => UserRepository(getIt<AppDatabase>()));
// ... more repositories
```

### Navigation/Routing

**File**: `lib/core/routing/app_router.dart`

**Route Structure**:
```
/                           # Welcome screen
/role-selection             # Choose caregiver/dependent
/profile-setup              # Complete profile
/login                      # Login (with role parameter)
/register                   # Registration
/email-verification         # Verify email code

/caregiver                  # Caregiver home
  └── /dependent/:id        # Dependent dashboard
      ├── /add-reminder     # Create reminder
      └── /emergency-contacts

/dependent                  # Dependent home
  ├── /reminder/:id         # Reminder alert
  └── /sos                  # SOS screen

/settings                   # App settings
```

---

## 4. Data Layer

### Local Database (Drift/SQLite)

**File**: `lib/data/datasources/local/database.dart`

#### Schema (7 Tables)

**1. Users**
```dart
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get role => text()();  // 'caregiver' | 'dependent'
  TextColumn get uniqueCode => text()();  // 9-char code
  BoolColumn get emailVerified => boolean().withDefault(const Constant(false))();
  // ... more fields
}
```

**2. CareRelationships**
```dart
class CareRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get caregiverId => text()();
  TextColumn get dependentId => text()();
  TextColumn get status => text()();  // 'pending' | 'active' | 'removed'
  TextColumn get linkingCode => text().nullable()();
  // ... more fields
}
```

**3. Reminders** (Templates)
```dart
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get creatorId => text()();
  TextColumn get dependentId => text()();
  TextColumn get title => text()();
  TextColumn get repeatPattern => text()();  // 'once' | 'daily' | 'weekly' | 'specific_days'
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get priority => text()();  // 'normal' | 'high'
  // ... more fields
}
```

**4. ReminderInstances** (Individual Occurrences)
```dart
class ReminderInstances extends Table {
  TextColumn get id => text()();
  TextColumn get reminderId => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  TextColumn get status => text()();  // 'pending' | 'completed' | 'missed' | 'snoozed'
  IntColumn get escalationLevel => integer().withDefault(const Constant(0))();
  // ... more fields
}
```

**5. SosEvents**
```dart
class SosEvents extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text()();
  TextColumn get status => text()();  // 'triggered' | 'cancelled' | 'resolved'
  DateTimeColumn get triggeredAt => dateTime()();
  // ... more fields
}
```

**6. EmergencyContacts**
```dart
class EmergencyContacts extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text()();
  TextColumn get name => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get relationship => text()();  // 'family' | 'doctor' | 'neighbor'
  // ... more fields
}
```

**7. AppSettings** (Key-Value Store)
```dart
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
}
```

### Remote APIs

**Base URL**: `https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net`

#### API Client (`lib/data/datasources/remote/api_client.dart`)

Features:
- JWT Bearer token authentication
- Automatic token refresh (5-minute buffer before expiry)
- Secure token storage (flutter_secure_storage)
- Methods: GET, POST, PUT, DELETE, uploadFile
- 30-second timeout per request

#### API Services

| Service | File | Endpoints |
|---------|------|-----------|
| AuthApi | `auth_api.dart` | `/api/auth/*` |
| UserApi | `user_api.dart` | `/api/users/*` |
| ReminderApi | `reminder_api.dart` | `/api/reminders/*` |
| ReminderInstanceApi | `reminder_instance_api.dart` | `/api/reminder-instances/*` |
| RelationshipApi | `relationship_api.dart` | `/api/relationships/*` |
| SosApi | `sos_api.dart` | `/api/sos/*` |
| SignalRService | `signalr_service.dart` | `/hubs/sync` (WebSocket) |

### Repositories

| Repository | Purpose |
|------------|---------|
| UserRepository | User authentication, profile management |
| ReminderRepository | Reminder CRUD, instance management |
| CareRelationshipRepository | Linking caregivers and dependents |
| SosRepository | SOS event management |
| SettingsRepository | App preferences |

---

## 5. Features

### 5.1 Authentication

**Screens**:
- WelcomeScreen - App introduction
- RoleSelectionScreen - Choose caregiver/dependent
- RegistrationScreen - Sign up with email/password
- LoginScreen - Sign in
- EmailVerificationScreen - Verify email code
- ProfileSetupScreen - Complete profile

**Auth Flow**:
```
Registration → Email Verification → Profile Setup → Home Screen
     or
Login → Home Screen (if verified)
```

### 5.2 Caregiver Features

**CaregiverHomeScreen** (`lib/features/caregiver/presentation/screens/caregiver_home_screen.dart`)
- Dashboard showing linked dependents
- Unique code display for linking
- Add dependent functionality
- Settings access

**DependentDashboardScreen** (`lib/features/caregiver/presentation/screens/dependent_dashboard_screen.dart`)
- View specific dependent's reminders
- Today's reminders summary (completed/pending/missed)
- Create and edit reminders
- Manage emergency contacts

### 5.3 Dependent Features

**DependentHomeScreen** (`lib/features/dependent/presentation/screens/dependent_home_screen.dart`)
- View today's reminders
- Large SOS button
- Pending link request notifications
- Complete/snooze reminders
- Background refresh (no loading flash)

### 5.4 Reminder System

**Two-Layer Architecture**:

1. **Reminder Template** - Defines recurring pattern
   - Created by caregiver
   - Repeat patterns: once, daily, weekly, specific_days
   - Priority levels: normal, high
   - Optional voice note

2. **ReminderInstance** - Individual occurrence
   - Generated from template by backend
   - Independent status tracking
   - Escalation levels (0-2)

**Escalation Levels**:
| Level | Name | Timing |
|-------|------|--------|
| 0 | Gentle | After 5 minutes |
| 1 | Repeat | After 10 minutes |
| 2 | Full-screen | After 15 minutes |

### 5.5 SOS Emergency System

**Flow**:
1. Dependent long-presses SOS button (3 seconds)
2. 10-second cancellation window appears
3. If not cancelled, SOS event triggers
4. Caregivers receive real-time notification
5. Caregiver can resolve SOS with notes

---

## 6. Backend API

### Controllers

#### AuthController (`/api/auth`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | Register new user |
| POST | `/login` | Login with email/password |
| POST | `/refresh-token` | Refresh JWT token |
| POST | `/verify-email` | Verify email code |
| POST | `/logout` | Logout user |

#### UsersController (`/api/users`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/current` | Get current user |
| GET | `/search` | Search by unique code/email |
| PUT | `/profile` | Update profile |
| POST | `/device-token` | Register push token |

#### RemindersController (`/api/reminders`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Get reminders (filtered by role) |
| GET | `/:id` | Get reminder by ID |
| POST | `/` | Create reminder |
| PUT | `/:id` | Update reminder |
| DELETE | `/:id` | Delete reminder |

#### ReminderInstancesController (`/api/reminder-instances`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Get instances (by date/dependent) |
| PUT | `/:id/complete` | Mark as completed |
| PUT | `/:id/miss` | Mark as missed |
| PUT | `/:id/snooze` | Snooze instance |
| PUT | `/:id/escalate` | Increase escalation |

#### RelationshipsController (`/api/relationships`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Get relationships |
| GET | `/pending` | Get pending link requests |
| POST | `/` | Create relationship |
| POST | `/:id/verify` | Verify linking code |
| DELETE | `/:id` | Remove relationship |

#### SosController (`/api/sos`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Get SOS events |
| GET | `/active` | Get active SOS |
| POST | `/` | Trigger SOS |
| PUT | `/:id/resolve` | Resolve SOS |
| PUT | `/:id/cancel` | Cancel SOS |

### Services

| Service | Purpose |
|---------|---------|
| TokenService | JWT token generation/validation |
| AuthService | Password hashing, code generation |
| NotificationService | Push notifications (stub) |
| BlobStorageService | Azure Blob file uploads |
| ReminderInstanceBackgroundService | Instance generation & missed marking |

---

## 7. Real-time Communication

### SignalR Hub

**File**: `ParentalCareApi/Hubs/SyncHub.cs`
**Mobile**: `lib/data/datasources/remote/signalr_service.dart`

**Hub URL**: `/hubs/sync`

### Events

#### Link Events
| Event | Direction | Description |
|-------|-----------|-------------|
| LinkRequestReceived | Server → Client | New link request |
| LinkVerified | Server → Client | Link verified |
| LinkRemoved | Server → Client | Link removed |

#### Reminder Events
| Event | Direction | Description |
|-------|-----------|-------------|
| ReminderCreated | Server → Client | New reminder created |
| ReminderUpdated | Server → Client | Reminder modified |
| ReminderDeleted | Server → Client | Reminder deleted |

#### Instance Events
| Event | Direction | Description |
|-------|-----------|-------------|
| InstanceCreated | Server → Client | New instance generated |
| InstanceStatusChanged | Server → Client | Instance status changed |

#### SOS Events
| Event | Direction | Description |
|-------|-----------|-------------|
| SosTriggered | Server → Client | SOS activated |
| SosResolved | Server → Client | SOS resolved |
| SosCancelled | Server → Client | SOS cancelled |

### Connection Management

```dart
// Auto-reconnect: Up to 10 attempts, 5-second delays
// Keep-alive: Ping/Pong every 30 seconds
// Group-based messaging: user:{userId}, dependent:{dependentId}
```

---

## 8. Authentication & Security

### Password Security

```dart
// Client-side (Dart)
// SHA-256 hash with random salt
// Format: base64(salt):hexdigest(hash)
String hashPassword(String password) {
  final salt = _generateSalt();
  final hash = sha256.convert(utf8.encode(salt + password));
  return '${base64.encode(utf8.encode(salt))}:${hash.toString()}';
}
```

### JWT Token Flow

```
1. Login: POST /api/auth/login { email, passwordHash }
2. Server validates, generates tokens
3. Response: { accessToken (15min), refreshToken (7d), expiresAt }
4. Client stores in flutter_secure_storage

Token Refresh (automatic):
- Client monitors token expiry
- 5 minutes before expiry: POST /api/auth/refresh-token
- Updates secure storage
```

### Authorization

- JWT Bearer in `Authorization` header
- Role-based access control (caregiver/dependent)
- Resource ownership validation

---

## 9. Key Workflows

### 9.1 Care Relationship Linking

```
1. Caregiver enters dependent's unique code
2. POST /api/relationships → Creates pending relationship
3. Server generates 5-digit linking code
4. SignalR: LinkRequestReceived → Dependent

5. Dependent sees banner, enters code
6. POST /api/relationships/:id/verify
7. Server validates, activates relationship
8. SignalR: LinkVerified → Both parties
```

### 9.2 Reminder Creation & Delivery

```
1. Caregiver creates reminder template
2. POST /api/reminders → Saved to database
3. Background service generates instances (7-day window)
4. SignalR: InstanceCreated → Dependent

5. Dependent sees reminder at scheduled time
6. Can complete, snooze, or let it escalate
7. PUT /api/reminder-instances/:id/complete
8. SignalR: InstanceStatusChanged → Caregiver
```

### 9.3 SOS Emergency Flow

```
1. Dependent long-presses SOS button (3 seconds)
2. POST /api/sos → Creates event
3. SignalR: SosTriggered → All caregivers

4. 10-second cancellation window
   - If cancelled: PUT /api/sos/:id/cancel
   - If not: Event remains triggered

5. Caregiver resolves: PUT /api/sos/:id/resolve
6. SignalR: SosResolved → Dependent
```

---

## 10. Configuration

### App Configuration

**File**: `lib/core/constants/app_config.dart`

```dart
class AppConfig {
  static const bool useRemoteBackend = true;
  static const bool enablePushNotifications = false;
  static const bool enableVoiceNoteCloudBackup = false;

  static const int maxVoiceNoteDurationSeconds = 60;
  static const int sosLongPressDurationMs = 3000;
  static const int sosCancellationWindowSeconds = 10;

  static const int gentleReminderIntervalMinutes = 5;
  static const int repeatReminderIntervalMinutes = 10;
  static const int fullScreenReminderIntervalMinutes = 15;
}
```

### MVP Hardcoded Codes (Testing Only)

```
Email Verification Code: "123456"
Login Code:              "123456"
Linking Code:            "12345"
```

---

## 11. Dependencies

### Flutter (pubspec.yaml)

```yaml
dependencies:
  # UI & State
  flutter_bloc: ^9.1.1
  go_router: ^15.1.2
  equatable: ^2.0.7

  # Data
  drift: ^2.24.0
  sqlite3_flutter_libs: ^0.5.29
  http: ^1.2.0
  signalr_netcore: ^1.3.7

  # Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.5.3
  path_provider: ^2.1.5

  # DI
  get_it: ^8.0.3
  injectable: ^2.6.2

  # Notifications
  flutter_local_notifications: ^18.0.1
  timezone: ^0.10.0

  # Audio
  record: ^6.1.2
  audioplayers: ^6.4.0

  # Other
  uuid: ^4.5.1
  crypto: ^3.0.6
  intl: ^0.20.2
```

### Backend (.NET 8)

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" />
<PackageReference Include="Swashbuckle.AspNetCore" />
<PackageReference Include="Azure.Storage.Blobs" />
<PackageReference Include="BCrypt.Net-Next" />
```

---

## 12. Known Limitations & TODOs

### Mobile App
- [ ] Push notifications (FCM/APNs not integrated)
- [ ] Voice note cloud backup
- [ ] Background task scheduling
- [ ] Unit/integration tests
- [ ] Better error handling/recovery

### Backend API
- [ ] Email verification service (currently stub)
- [ ] Push notification service (currently stub)
- [ ] Rate limiting
- [ ] Input validation improvements
- [ ] Audit logging
- [ ] API versioning

### Infrastructure
- [ ] Database migrations automation
- [ ] Caching layer (Redis)
- [ ] Load balancing
- [ ] Error tracking (Sentry/App Insights)
- [ ] Analytics integration

---

## Quick Reference

### Key File Paths

| Purpose | Path |
|---------|------|
| DI Setup | `lib/core/di/injection.dart` |
| Routing | `lib/core/routing/app_router.dart` |
| Database Schema | `lib/data/datasources/local/database.dart` |
| API Client | `lib/data/datasources/remote/api_client.dart` |
| SignalR Service | `lib/data/datasources/remote/signalr_service.dart` |
| Dependent Home | `lib/features/dependent/presentation/screens/dependent_home_screen.dart` |
| Caregiver Home | `lib/features/caregiver/presentation/screens/caregiver_home_screen.dart` |
| Backend Startup | `ParentalCareApi/Program.cs` |
| Reminders API | `ParentalCareApi/Controllers/RemindersController.cs` |
| SignalR Hub | `ParentalCareApi/Hubs/SyncHub.cs` |

### API Base URL

**Production**: `https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net`

### Health Check

```bash
curl https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/health
```

---

*Document generated: February 2026*
*App Version: 1.0.0*
