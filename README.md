# Remote Caregiver App

A Flutter mobile application for caregivers and dependents to stay connected through reminders, notifications, and emergency alerts.

## Features

- **Two User Roles**: Caregiver and Dependent modes
- **User Linking**: Connect caregivers with dependents using unique codes
- **Reminders**: Create and manage reminders with voice notes
- **SOS Alerts**: Emergency alert system for dependents
- **Cross-Device Sync**: Data synchronized via Azure cloud backend
- **Email Verification**: Secure account verification

## Architecture

```
├── Flutter App (iOS/Android)
│   ├── Clean Architecture (Domain, Data, Presentation)
│   ├── GetIt for dependency injection
│   ├── GoRouter for navigation
│   └── Drift for local database
│
└── Azure Backend (ASP.NET Core 8.0)
    ├── REST API
    ├── Azure SQL Database
    ├── JWT Authentication
    └── Azure Blob Storage
```

## Prerequisites

### For Flutter App

- Flutter SDK 3.x or later
- Dart SDK 3.x or later
- Xcode 15+ (for iOS development)
- Android Studio (for Android development)
- CocoaPods (for iOS dependencies)

### For Backend Development

- .NET 8.0 SDK
- Azure CLI (for deployment)
- SQL Server or Azure SQL Database

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/prasadmagre/remotecaregiver.git
cd remotecaregiver
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. iOS Setup

```bash
cd ios
pod install
cd ..
```

### 4. Run the App

#### On iOS Simulator

```bash
# List available simulators
flutter devices

# Run on specific simulator
flutter run -d "iPhone 17 Pro"

# Or run on any available iOS simulator
flutter run
```

#### On Android Emulator

```bash
flutter run -d android
```

#### On Multiple Devices

```bash
# Run on two simulators simultaneously
flutter run -d <device-id-1> &
flutter run -d <device-id-2>
```

## Development

### Project Structure

```
lib/
├── app.dart                    # App entry point and router setup
├── main.dart                   # Main function
├── core/
│   ├── constants/              # App constants, colors, spacing
│   ├── di/                     # Dependency injection setup
│   ├── routing/                # GoRouter configuration
│   └── theme/                  # App theming
├── data/
│   ├── datasources/
│   │   ├── local/              # Drift database
│   │   └── remote/             # API clients
│   └── repositories/           # Data repositories
├── features/
│   ├── auth/                   # Authentication screens
│   ├── caregiver/              # Caregiver-specific features
│   ├── dependent/              # Dependent-specific features
│   ├── onboarding/             # Welcome and role selection
│   └── settings/               # App settings
└── shared/
    ├── models/                 # Shared data models
    └── widgets/                # Reusable widgets
```

### Backend API

The app connects to an Azure-hosted REST API:

```
Base URL: https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net
```

#### Key Endpoints

- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - Email/password login
- `POST /api/auth/login-code` - Login with verification code
- `POST /api/auth/verify-email` - Email verification
- `GET /api/users/me` - Get current user profile
- `GET /api/users/code/{code}` - Find user by unique code

### Testing Authentication

For development/testing, use verification code: `123456`

### Building for Production

#### iOS

```bash
flutter build ios --release
```

#### Android

```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

## Backend Deployment

See [ParentalCareApi/DEPLOYMENT.md](ParentalCareApi/DEPLOYMENT.md) for detailed Azure deployment instructions.

### Quick Backend Deploy

#### macOS/Linux (bash)

```bash
cd ParentalCareApi

# Build
dotnet publish -c Release -o ./publish

# Create deployment package
cd publish && zip -r ../deploy.zip . && cd ..

# Deploy to Azure
az webapp deploy \
  --resource-group RemoteCaregiverRG \
  --name remotecaregiver-api \
  --src-path ./deploy.zip \
  --type zip
```

#### Windows (PowerShell)

```powershell
cd ParentalCareApi

# One-time: az login

./deploy.ps1 -AppName "remotecaregiver-api" -ResourceGroup "RemoteCaregiverRG"
```

## Configuration

### API Base URL

Update the API URL in `lib/data/datasources/remote/api_client.dart`:

```dart
static const String _defaultBaseUrl = 'https://your-api-url.azurewebsites.net';
```

### Environment Variables

For backend, configure these in Azure App Settings or `appsettings.json`:

- `ConnectionStrings__DefaultConnection` - Database connection
- `Jwt__Key` - JWT signing key (32+ characters)
- `Jwt__Issuer` - Token issuer name
- `Jwt__Audience` - Token audience name

## Testing

### Run Unit Tests

```bash
flutter test
```

### Run Integration Tests

```bash
flutter test integration_test/
```

## Troubleshooting

### Common Issues

1. **iOS build fails**: Run `cd ios && pod install && cd ..`
2. **Dependency conflicts**: Run `flutter clean && flutter pub get`
3. **API connection errors**: Check the base URL in `api_client.dart`
4. **401 Unauthorized**: Re-login to refresh JWT token

### Debug Mode

Enable debug logging by checking console output during `flutter run`.

### Hot Reload

While running:

- Press `r` for hot reload
- Press `R` for hot restart
- Press `q` to quit

## Using GitHub Spark

[GitHub Spark](https://github.com/features/spark) is GitHub's AI-powered tool for creating and iterating on apps using natural language. You can use Spark to explore, modify, or build on top of this repository.

### Prerequisites

- A GitHub account with a **Copilot Pro+** or **Enterprise** subscription ([learn more](https://docs.github.com/en/copilot/concepts/spark))

### Steps to Open This Repo in a New GitHub Spark Session

1. **Go to GitHub Spark**  
   Navigate to [spark.github.com](https://spark.github.com) and sign in with your GitHub account.

2. **Create a New Spark**  
   Click **"New Spark"** (or the **"+"** button) on the Spark dashboard.

3. **Connect to this Repository**  
   - In the new spark session, look for the **repository / Git integration** option.
   - Search for `tlunawat1/githubsparkcaregiver` and select it.
   - Spark will sync your session with the current code and history.

4. **Describe What You Want to Build or Change**  
   Use the natural-language prompt box to tell Spark what you'd like to do — for example:
   - *"Add a new screen showing the caregiver's activity log"*
   - *"Create a summary page for completed reminders this week"*
   - *"Help me understand the reminder escalation flow"*

5. **Iterate with AI Assistance**  
   Spark will suggest code changes, generate new files, and give you a live preview. Accept, reject, or refine the suggestions using follow-up prompts.

6. **Open in Codespace (Optional)**  
   For a full cloud-based VS Code environment with terminal access, click **"Open in Codespace"** inside Spark. This gives you access to `flutter`, `dotnet`, and all other CLI tools needed for this project.

7. **Sync Changes Back**  
   Changes made in Spark are automatically synchronized to the repository — push them to a branch or open a pull request directly from the Spark interface.

> **Note:** The `.github/copilot-instructions.md` file in this repository provides Spark and Copilot with project-specific context (architecture, coding conventions, key flows) so AI suggestions are accurate and consistent with the existing codebase.

### Useful Links

| Resource | URL |
|----------|-----|
| GitHub Spark | https://spark.github.com |
| Spark documentation | https://docs.github.com/en/copilot/concepts/spark |
| Spark tutorial | https://docs.github.com/en/copilot/tutorials/spark |
| Spark user manual | https://github.com/githubnext/github-spark-user-manual |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is proprietary software.

## Support

For issues and questions, please open a GitHub issue.

To deploy and build backend

Bash(/opt/homebrew/opt/dotnet@8/bin/dotnet build /Users/pmagre/MobileApp/ParentalCareApi 2>&1)  
 az webapp deploy --resource-group RemoteCaregiverRG --name RemoteCareGiver-api --src-path /Users/pmagre/MobileApp/ParentalCareApi/deploy.zip  
 --type zip 2>&1

https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/health

⏺ Bash(xcrun simctl uninstall 80F54299-B78B-4984-B72B-4BDF509AB26A com.parentalcare.parentalCareApp 2>/dev/null || echo "App not installed on iPhone
17 Pro")

⏺ Bash(xcrun simctl uninstall 7CA51281-D717-48D9-9E81-0348D3C11006 com.parentalcare.parentalCareApp 2>/dev/null || echo "App not installed on iPhone
17")

Bash(flutter run -d 80F54299-B78B-4984-B72B-4BDF509AB26A)

⎿ Waiting…un simctl uninstall 80F54299-B78B-4984-B72B-4BDF509AB26A com.parentalcare.parentalCareApp && echo "✓ Uninstalled from iPhone 17 Pro")

     Waiting…un simctl uninstall 7CA51281-D717-48D9-9E81-0348D3C11006 com.parentalcare.parentalCareApp && echo "✓ Uninstalled from iPhone 17")
