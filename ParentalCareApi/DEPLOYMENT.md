# Azure Backend Deployment Guide

This guide explains how to deploy the ParentalCare API to Azure.

## Prerequisites

- Azure subscription
- Azure CLI installed (`az`)
- .NET 8.0 SDK installed
- Git

## 1. Azure Resources Setup

### Create Resource Group
```bash
az group create --name ParentalCareRG --location eastus
```

### Create Azure SQL Database
```bash
# Create SQL Server
az sql server create \
  --name parentalcare-sql-server \
  --resource-group ParentalCareRG \
  --location eastus \
  --admin-user sqladmin \
  --admin-password "YourSecurePassword123!"

# Create Database
az sql db create \
  --resource-group ParentalCareRG \
  --server parentalcare-sql-server \
  --name ParentalCareDb \
  --service-objective Basic

# Configure firewall to allow Azure services
az sql server firewall-rule create \
  --resource-group ParentalCareRG \
  --server parentalcare-sql-server \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Create App Service
```bash
# Create App Service Plan
az appservice plan create \
  --name ParentalCarePlan \
  --resource-group ParentalCareRG \
  --sku B1 \
  --is-linux

# Create Web App
az webapp create \
  --name parentalcare-api \
  --resource-group ParentalCareRG \
  --plan ParentalCarePlan \
  --runtime "DOTNETCORE:8.0"
```

### Create Storage Account (for voice notes)
```bash
az storage account create \
  --name parentalcarestorage \
  --resource-group ParentalCareRG \
  --location eastus \
  --sku Standard_LRS

# Create blob container
az storage container create \
  --name uploads \
  --account-name parentalcarestorage \
  --public-access blob
```

## 2. Configure Application Settings

```bash
# Get SQL connection string
SQL_CONNECTION=$(az sql db show-connection-string \
  --server parentalcare-sql-server \
  --name ParentalCareDb \
  --client ado.net \
  --output tsv)

# Get Storage connection string
STORAGE_CONNECTION=$(az storage account show-connection-string \
  --name parentalcarestorage \
  --resource-group ParentalCareRG \
  --output tsv)

# Configure app settings
az webapp config appsettings set \
  --name parentalcare-api \
  --resource-group ParentalCareRG \
  --settings \
    ConnectionStrings__DefaultConnection="$SQL_CONNECTION" \
    Azure__BlobStorage__ConnectionString="$STORAGE_CONNECTION" \
    Azure__BlobStorage__ContainerName="uploads" \
    Jwt__Key="YourProductionJwtKeyHereMustBeAtLeast32Characters!" \
    Jwt__Issuer="ParentalCareApi" \
    Jwt__Audience="ParentalCareApp"
```

## 3. Initialize Database

Run the SQL script to create tables:

```bash
# Using Azure Cloud Shell or SQL Server Management Studio
sqlcmd -S parentalcare-sql-server.database.windows.net \
  -d ParentalCareDb \
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

### Option A: Using GitHub Actions (Recommended)

1. Get the publish profile:
```bash
az webapp deployment list-publishing-profiles \
  --name parentalcare-api \
  --resource-group ParentalCareRG \
  --xml > publish-profile.xml
```

2. Add the publish profile as a GitHub secret:
   - Go to your GitHub repo → Settings → Secrets
   - Add new secret: `AZURE_WEBAPP_PUBLISH_PROFILE`
   - Paste the contents of `publish-profile.xml`

3. Update `.github/workflows/azure-deploy.yml`:
   - Set `AZURE_WEBAPP_NAME` to `parentalcare-api`

4. Push to `main` branch to trigger deployment

### Option B: Using Azure CLI

```bash
cd ParentalCareApi

# Build and publish
dotnet publish -c Release -o ./publish

# Deploy
az webapp deploy \
  --resource-group ParentalCareRG \
  --name parentalcare-api \
  --src-path ./publish \
  --type zip
```

### Option C: Using Docker

```bash
# Build image
docker build -t parentalcare-api .

# Tag for Azure Container Registry (if using ACR)
docker tag parentalcare-api parentalcareacr.azurecr.io/parentalcare-api:latest

# Push to registry
docker push parentalcareacr.azurecr.io/parentalcare-api:latest
```

## 5. Verify Deployment

```bash
# Check health endpoint
curl https://parentalcare-api.azurewebsites.net/health

# Expected response:
# {"status":"healthy","timestamp":"2024-..."}
```

## 6. Configure Flutter App

Update the API base URL in your Flutter app:

```dart
// lib/data/datasources/remote/api_client.dart
static const String _defaultBaseUrl = 'https://parentalcare-api.azurewebsites.net';
```

For SignalR:
```dart
// lib/data/datasources/remote/signalr_service.dart
static const String _defaultHubUrl = 'https://parentalcare-api.azurewebsites.net/hubs/sync';
```

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
  --name parentalcare-api \
  --resource-group ParentalCareRG
```

### Restart App
```bash
az webapp restart \
  --name parentalcare-api \
  --resource-group ParentalCareRG
```

### Scale Up (if needed)
```bash
az appservice plan update \
  --name ParentalCarePlan \
  --resource-group ParentalCareRG \
  --sku S1
```

## Security Checklist

- [ ] Change default SQL admin password
- [ ] Generate secure JWT key (32+ characters)
- [ ] Enable HTTPS only
- [ ] Configure CORS for production domains
- [ ] Set up Azure Key Vault for secrets
- [ ] Enable Application Insights for monitoring
- [ ] Configure backup for SQL Database
