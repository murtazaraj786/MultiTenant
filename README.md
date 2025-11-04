# Microsoft Sentinel Multi-Tenant Incident Synchronization

## Overview

This solution enables cross-tenant incident synchronization for Microsoft Sentinel using Azure Lighthouse and Logic Apps. It automatically retrieves incidents from delegated Sentinel instances and imports them into a central Sentinel instance for unified security operations.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Main Tenant (Central)                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Microsoft Sentinel (Main Instance)             │ │
│  │                                                        │ │
│  │  • Aggregated Incidents                               │ │
│  │  • Unified Dashboard                                  │ │
│  │  • Central SOC Operations                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ▲                                │
│                            │                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Logic App (Orchestrator)                  │ │
│  │                                                        │ │
│  │  • Scheduled Trigger (Every 5 minutes)                │ │
│  │  • Query Delegated Tenants                            │ │
│  │  • Transform Incident Data                            │ │
│  │  • Create/Update Incidents                            │ │
│  │  • Error Handling & Logging                           │ │
│  └────────────────────────────────────────────────────────┘ │
│                            │                                │
│                   Azure Lighthouse                          │
└────────────────────────────┼───────────────────────────────┘
                             │
         ┌───────────────────┴───────────────────┐
         │                                       │
┌────────▼────────────┐              ┌──────────▼──────────┐
│  Delegated Tenant 1 │              │  Delegated Tenant N │
│                     │              │                     │
│  ┌──────────────┐   │              │  ┌──────────────┐   │
│  │   Sentinel   │   │              │  │   Sentinel   │   │
│  │   Instance   │   │      ...     │  │   Instance   │   │
│  │              │   │              │  │              │   │
│  └──────────────┘   │              │  └──────────────┘   │
└─────────────────────┘              └─────────────────────┘
```

## Key Features

- **Multi-Tenant Support**: Synchronize incidents from multiple Azure tenants via Lighthouse
- **Automated Sync**: Scheduled polling for new and updated incidents
- **Bi-directional Mapping**: Track original incidents and prevent duplicates
- **Configurable Filters**: Control which incidents to sync (severity, status, etc.)
- **Error Handling**: Comprehensive logging and retry mechanisms
- **Managed Identity**: Secure authentication without credentials

## Prerequisites

### Azure Lighthouse Setup
1. **Delegated Access**: Customer tenants must delegate access to your service provider tenant
2. **Required Permissions**:
   - `Microsoft Sentinel Contributor` on delegated subscriptions
   - `Log Analytics Reader` on delegated workspaces

### Main Tenant Requirements
1. **Microsoft Sentinel**: Deployed with Log Analytics workspace
2. **Managed Identity**: System-assigned or user-assigned with appropriate permissions
3. **API Permissions**: Microsoft Sentinel API access

## Project Structure

```
.
├── .github/
│   └── copilot-instructions.md          # Copilot context and guidelines
├── deployment/
│   ├── arm-templates/
│   │   ├── logic-app.json               # Logic App ARM template
│   │   ├── logic-app.parameters.json    # Parameters file
│   │   ├── api-connections.json         # API connections template
│   │   └── managed-identity.json        # Managed identity setup
│   └── scripts/
│       ├── Deploy-Solution.ps1          # Main deployment script
│       ├── Setup-Lighthouse.ps1         # Lighthouse configuration helper
│       └── Grant-Permissions.ps1        # Permission assignment script
├── logic-app/
│   ├── workflow.json                    # Logic App workflow definition
│   └── connections.json                 # Connection references
├── config/
│   ├── tenants.json                     # Tenant configuration
│   ├── sync-settings.json               # Synchronization settings
│   └── field-mappings.json              # Incident field mappings
├── docs/
│   ├── ARCHITECTURE.md                  # Architecture documentation
│   ├── DEPLOYMENT.md                    # Deployment guide
│   ├── CONFIGURATION.md                 # Configuration reference
│   └── TROUBLESHOOTING.md              # Common issues and solutions
└── README.md                            # This file
```

## Quick Start

### Deployment Options

**Choose your preferred deployment method:**

#### Option 1: Azure Portal (Easiest - GUI)
Perfect for first-time setup with guided interface and auto-populated fields.

1. Go to [Azure Portal Custom Deployment](https://portal.azure.com/#create/Microsoft.Template)
2. Click **"Build your own template in the editor"**
3. Load `deployment/arm-templates/portal-deployment.json`
4. Fill in the form (subscription/RG auto-populated)
5. Click **"Review + create"**

📖 **See:** [`docs/PORTAL-DEPLOYMENT.md`](docs/PORTAL-DEPLOYMENT.md) for detailed GUI deployment guide

#### Option 2: PowerShell (Automated)
Best for automation, CI/CD, and repeatable deployments.

```powershell
# Navigate to deployment scripts
cd deployment/scripts

# Login to Azure
Connect-AzAccount

# Run deployment
./Deploy-Solution.ps1 `
    -SubscriptionId "<your-subscription-id>" `
    -ResourceGroupName "sentinel-sync-rg" `
    -Location "eastus" `
    -LogicAppName "sentinel-incident-sync" `
    -MainTenantId "<your-main-tenant-id>" `
    -MainSubscriptionId "<your-main-subscription-id>" `
    -MainResourceGroup "sentinel-main-rg" `
    -MainWorkspaceName "main-sentinel-workspace"
```

📖 **See:** [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for detailed PowerShell deployment guide

---

### 1. Configure Tenants

Edit `config/tenants.json` with your delegated tenant details:

```json
{
  "delegatedTenants": [
    {
      "tenantId": "00000000-0000-0000-0000-000000000000",
      "subscriptionId": "00000000-0000-0000-0000-000000000000",
      "resourceGroup": "sentinel-rg",
      "workspaceName": "customer-sentinel-workspace",
      "enabled": true
    }
  ]
}
```

### 2. Deploy the Solution

See **Deployment Options** above - choose Portal or PowerShell method.

### 3. Configure Sync Settings

Edit `config/sync-settings.json` to customize:
- Sync frequency
- Incident filters (severity, status)
- Field mappings
- Retention policies

### 4. Verify Deployment

```powershell
# Check Logic App status
Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"

# View run history
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"
```

## Configuration

### Sync Settings

Configure in `config/sync-settings.json`:

- **syncFrequency**: How often to check for new incidents (minutes)
- **lookbackPeriod**: How far back to look for incidents (days)
- **severityFilter**: Array of severities to sync (High, Medium, Low, Informational)
- **statusFilter**: Array of statuses to sync (New, Active, Closed)
- **deduplication**: Enable/disable duplicate detection

### Field Mappings

Customize incident field mappings in `config/field-mappings.json` to control:
- Which fields to sync
- Field transformations
- Custom properties
- Source tenant tagging

## Incident Synchronization Flow

1. **Trigger**: Logic App runs on schedule (default: every 5 minutes)
2. **Authentication**: Uses managed identity to authenticate
3. **Query**: Queries each delegated tenant's Sentinel instance via Lighthouse
4. **Filter**: Applies configured filters (severity, status, timeframe)
5. **Transform**: Maps incident fields from source to destination
6. **Deduplication**: Checks for existing incidents to prevent duplicates
7. **Create/Update**: Creates new incidents or updates existing ones in main tenant
8. **Logging**: Records sync results and any errors

## Security Considerations

- **Managed Identity**: No credentials stored; uses Azure AD authentication
- **Least Privilege**: Grant only required permissions on delegated tenants
- **Audit Logging**: All sync operations are logged
- **Data Residency**: Review compliance requirements for cross-tenant data
- **API Throttling**: Implements retry logic for API limits

## Monitoring and Troubleshooting

### View Logs

```powershell
# Logic App run history
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" | Select-Object -First 10

# Failed runs
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" | Where-Object {$_.Status -eq "Failed"}
```

### Common Issues

See `docs/TROUBLESHOOTING.md` for detailed troubleshooting steps.

## Costs

Estimated monthly costs (subject to change):
- **Logic App**: ~$0.025 per action execution
- **API Calls**: Included with Sentinel license
- **Storage**: Minimal for state management

## Contributing

This is a framework/template. Customize to your specific requirements:
- Add custom incident enrichment
- Implement bidirectional sync
- Add alerting for sync failures
- Extend to sync other Sentinel data (alerts, bookmarks)

## License

This is a sample solution for educational purposes. Review and test thoroughly before production use.

## Support

For issues related to:
- **Azure Lighthouse**: [Azure Lighthouse Documentation](https://docs.microsoft.com/azure/lighthouse/)
- **Microsoft Sentinel**: [Microsoft Sentinel Documentation](https://docs.microsoft.com/azure/sentinel/)
- **Logic Apps**: [Azure Logic Apps Documentation](https://docs.microsoft.com/azure/logic-apps/)

## Next Steps

1. Review `docs/ARCHITECTURE.md` for detailed architecture information
2. Follow `docs/DEPLOYMENT.md` for step-by-step deployment
3. Customize `config/` files for your environment
4. Test with a single delegated tenant before scaling
5. Set up monitoring and alerting for the Logic App

---

**Version**: 1.0.0  
**Last Updated**: November 2025
