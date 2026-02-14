# Azure Backend Deployment Guide

This guide explains how to deploy the Remote Caregiver API to Azure.

## Current Deployment

The currently running API is:
- **API URL**: `https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net`
- **Health Check**: `https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/health`

For safer rollout and rollback, create a **new** Web App and cut traffic over after verification.

## Prerequisites

- Azure subscription
- Azure CLI installed (`az`)
- .NET 8.0 SDK installed
- Git

## 1. Azure Resources Setup

### Create Resource Group
```bash
az group create --name RemoteCaregiverRG --location canadacentral
```

### Create Azure SQL Database
```bash
# Create SQL Server
az sql server create \
  --name remotecaregiver-sql-server \
  --resource-group RemoteCaregiverRG \
  --location canadacentral \
  --admin-user sqladmin \
  --admin-password "YourSecurePassword123!"

# Create Database
az sql db create \
  --resource-group RemoteCaregiverRG \
  --server remotecaregiver-sql-server \
  --name RemoteCaregiverDb \
  --service-objective Basic

# Configure firewall to allow Azure services
az sql server firewall-rule create \
  --resource-group RemoteCaregiverRG \
  --server remotecaregiver-sql-server \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Create App Service
```bash
APP_NAME="remotecaregiver-api-v2-$(date +%Y%m%d)"

# Create App Service Plan
az appservice plan create \
  --name RemoteCaregiverPlan \
  --resource-group RemoteCaregiverRG \
  --sku B1 \
  --is-linux

# Create Web App
az webapp create \
  --name "$APP_NAME" \
  --resource-group RemoteCaregiverRG \
  --plan RemoteCaregiverPlan \
  --runtime "DOTNETCORE:8.0"

# Print the new URL
echo "https://$APP_NAME.azurewebsites.net"
```

### Create Storage Account (for voice notes)
```bash
az storage account create \
  --name remotecaregiverstore \
  --resource-group RemoteCaregiverRG \
  --location canadacentral \
  --sku Standard_LRS

# Create blob container
az storage container create \
  --name uploads \
  --account-name remotecaregiverstore \
  --public-access blob
```

## 2. Configure Application Settings

```bash
APP_NAME="<your-new-webapp-name>"

# Get SQL connection string
SQL_CONNECTION=$(az sql db show-connection-string \
  --server remotecaregiver-sql-server \
  --name RemoteCaregiverDb \
  --client ado.net \
  --output tsv)

# Get Storage connection string
STORAGE_CONNECTION=$(az storage account show-connection-string \
  --name remotecaregiverstore \
  --resource-group RemoteCaregiverRG \
  --output tsv)

# Configure app settings
az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group RemoteCaregiverRG \
  --settings \
    ConnectionStrings__DefaultConnection="$SQL_CONNECTION" \
    AzureStorage__ConnectionString="$STORAGE_CONNECTION" \
    AzureStorage__ContainerName="uploads" \
    Jwt__Key="<32+ char random secret>" \
    Jwt__Issuer="RemoteCaregiverApi" \
    Jwt__Audience="RemoteCaregiverApp" \
    Firebase__ProjectId="parentalcareapp" \
    GOOGLE_APPLICATION_CREDENTIALS_JSON='<firebase-service-account-json>'
```

> Security note: keep `appsettings.json` secret-free. All sensitive values must be injected from App Settings / environment variables.

### Required App Settings / Environment Variables

**Connection / Auth**
- `ConnectionStrings__DefaultConnection` (required)
  - SQL Server ADO.NET connection string.
- `Jwt__Key` (required)
  - 32+ character secret key.
- `Jwt__Issuer` (optional, default: `ParentalCareApi`)
- `Jwt__Audience` (optional, default: `ParentalCareApp`)

**Firebase (Push Notifications)**
- `Firebase__ProjectId` (required for push)
- `GOOGLE_APPLICATION_CREDENTIALS_JSON` (preferred, required for push)
  - Raw JSON for the Firebase service account.
- `Firebase__CredentialsJson` (optional)
  - Alternate JSON source (config-based).
- `Firebase__CredentialsPath` (optional)
  - File path to a JSON file deployed alongside the app.

**Blob Storage (Voice Notes)**
- `AzureStorage__ConnectionString` (required for voice notes)
- `AzureStorage__ContainerName` (required, default: `uploads`)

**Hangfire**
- `Hangfire__WorkerCount` (optional, default: `5`)
- `Hangfire__DashboardPath` (optional, default: `/hangfire`)

**Notifications**
- `Notifications__EscalationDelayMinutes` (default: `5`)
- `Notifications__AutoMissDelayMinutes` (default: `30`)
- `Notifications__MissedGracePeriodMinutes` (default: `5`)
- `Notifications__MaxRetryCount` (default: `3`)
- `Notifications__DefaultTtlHours` (default: `4`)
- `Notifications__CallStyleEscalationLevel` (default: `2`)
  - Escalation level at which call-style full-screen alert is triggered.
- `Notifications__CallStyleTimeoutSeconds` (default: `120`)
  - Ring timeout for call-style alerts. `0` = no timeout.

**Email Verification (Azure Communication Services)**
- `EmailVerification__SenderAddress` (required for verification emails)
- `EmailVerification__VerificationCodeExpiryMinutes` (default: `10`)
- `EmailVerification__ResendCooldownSeconds` (default: `60`)

### Example app settings block (Azure)
```bash
az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group RemoteCaregiverRG \
  --settings \
    ConnectionStrings__DefaultConnection="$SQL_CONNECTION" \
    AzureStorage__ConnectionString="$STORAGE_CONNECTION" \
    AzureStorage__ContainerName="uploads" \
    Jwt__Key="<32+ char random secret>" \
    Jwt__Issuer="RemoteCaregiverApi" \
    Jwt__Audience="RemoteCaregiverApp" \
    Firebase__ProjectId="parentalcareapp" \
    GOOGLE_APPLICATION_CREDENTIALS_JSON='<firebase-service-account-json>' \
    Notifications__EscalationDelayMinutes="5" \
    Notifications__AutoMissDelayMinutes="30" \
    Notifications__MissedGracePeriodMinutes="5" \
    Notifications__CallStyleEscalationLevel="2" \
    Notifications__CallStyleTimeoutSeconds="120" \
    EmailVerification__SenderAddress="DoNotReply@your-acs-domain.azurecomm.net"
```

## 3. Initialize Database

Run the SQL script to create tables:

```bash
# Using Azure Cloud Shell or SQL Server Management Studio
sqlcmd -S remotecaregiver-sql-server.database.windows.net \
  -d RemoteCaregiverDb \
  -U sqladmin \
  -P "YourSecurePassword123!" \
  -i Scripts/InitDatabase.sql
```

Or use Azure Portal:
1. Go to your SQL Database
2. Click "Query editor (preview)"
3. Login and paste contents of `Scripts/InitDatabase.sql`
4. Click "Run"

## 4. Deploy the API

### Option A: Manual Deployment (Current Method)

```bash
cd ParentalCareApi
APP_NAME="<your-new-webapp-name>"

# Build and publish
dotnet publish -c Release -o ./publish

# Create zip file
cd publish && zip -r ../deploy.zip . && cd ..

# Deploy using Azure CLI
az webapp deploy \
  --resource-group RemoteCaregiverRG \
  --name "$APP_NAME" \
  --src-path ./deploy.zip \
  --type zip
```

### Option B: Using GitHub Actions

1. Get the publish profile:
```bash
APP_NAME="<your-new-webapp-name>"
az webapp deployment list-publishing-profiles \
  --name "$APP_NAME" \
  --resource-group RemoteCaregiverRG \
  --xml > publish-profile.xml
```

2. Add the publish profile as a GitHub secret:
   - Go to your GitHub repo → Settings → Secrets
   - Add new secret: `AZURE_WEBAPP_PUBLISH_PROFILE`
   - Paste the contents of `publish-profile.xml`

3. Create `.github/workflows/azure-deploy.yml` with deployment workflow

4. Push to `main` branch to trigger deployment

### Option C: Using Docker

```bash
# Build image
docker build -t remotecaregiver-api .

# Tag for Azure Container Registry (if using ACR)
docker tag remotecaregiver-api remotecaregiverregistry.azurecr.io/remotecaregiver-api:latest

# Push to registry
docker push remotecaregiverregistry.azurecr.io/remotecaregiver-api:latest
```

## 5. Verify Deployment

```bash
APP_NAME="<your-new-webapp-name>"

# Check health endpoint
curl "https://$APP_NAME.azurewebsites.net/health"

# Expected response:
# {"status":"healthy","timestamp":"2024-..."}

# Test registration endpoint
curl -X POST "https://$APP_NAME.azurewebsites.net/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","password":"test123","role":"caregiver"}'
```

## 6. Configure Flutter App

The API base URL is already configured in the Flutter app:

```dart
// lib/data/datasources/remote/api_client.dart
static const String _defaultBaseUrl = 'https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net';
```

After creating the new app, update this value (or move to environment-driven mobile config) to point to the new hostname.

## Cost Estimate

| Service | SKU | Monthly Cost |
|---------|-----|-------------|
| App Service | B1 | ~$13 |
| Azure SQL | Basic | ~$5 |
| Blob Storage | Hot | ~$1 |
| **Total** | | **~$19** |

## Troubleshooting

### Check Logs
```bash
az webapp log tail \
  --name "<your-new-webapp-name>" \
  --resource-group RemoteCaregiverRG
```

### Restart App
```bash
az webapp restart \
  --name "<your-new-webapp-name>" \
  --resource-group RemoteCaregiverRG
```

### Scale Up (if needed)
```bash
az appservice plan update \
  --name RemoteCaregiverPlan \
  --resource-group RemoteCaregiverRG \
  --sku S1
```

### Common Issues

1. **401 Unauthorized**: JWT token expired or invalid. Re-login to get new token.
2. **CORS errors**: Ensure CORS is configured in `Program.cs`.
3. **Database connection**: Check firewall rules allow Azure services.

## Security Checklist

- [ ] Change default SQL admin password
- [ ] Generate secure JWT key (32+ characters)
- [ ] Enable HTTPS only
- [ ] Configure CORS for production domains
- [ ] Set up Azure Key Vault for secrets
- [ ] Enable Application Insights for monitoring
- [ ] Configure backup for SQL Database

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/login-code` - Login with verification code
- `POST /api/auth/verify-email` - Verify email with code
- `POST /api/auth/refresh-token` - Refresh JWT token
- `POST /api/auth/send-verification-code` - Send new verification code
- `POST /api/auth/logout` - Logout (requires auth)

### Users
- `GET /api/users/me` - Get current user (requires auth)
- `PUT /api/users/me` - Update current user (requires auth)
- `GET /api/users/code/{code}` - Find user by unique code
- `GET /api/users/email/{email}` - Find user by email
- `PUT /api/users/device-token` - Update push notification token

## Database Tables (Initial + Runtime Schema Updates)

### Tables created by `Scripts/InitDatabase.sql`
- `Users`
- `CareRelationships`
- `Reminders`
- `ReminderInstances`
- `SosEvents`

### Tables created/updated at runtime (Program startup)
The API applies schema updates in `Program.cs`:

- **Users**
  - Adds `Timezone` (default `UTC`)
  - Adds `VerificationCodeSentAt`
- **ReminderInstances**
  - Adds `NotificationJobIds`
  - Adds `EscalationLevel`
- **UserDeviceTokens**
  - Stores multi-device FCM tokens
- **NotificationLogs**
  - Stores push notification delivery status
  - Adds `FcmMessageId`, `EscalationLevel` if missing

### Table purpose summary
- `Users`: accounts, roles, auth metadata, verification.
- `CareRelationships`: caregiver ↔ dependent links.
- `Reminders`: template reminders (repeat rules, time, priority).
- `ReminderInstances`: concrete scheduled reminders with status/escalation.
- `SosEvents`: SOS lifecycle state.
- `UserDeviceTokens`: per-device push tokens.
- `NotificationLogs`: audit trail of push deliveries.
