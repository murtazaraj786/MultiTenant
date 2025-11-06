# Multi-Tenant Sentinel Incident Sync# Multi-Tenant Sentinel Incident Sync - FIXED VERSION



![Status](https://img.shields.io/badge/status-production--ready-green) ![API](https://img.shields.io/badge/API-Sentinel%202023--02--01-blue) ![Platform](https://img.shields.io/badge/platform-Azure%20Logic%20Apps-orange)This Logic App **actually works** and creates incidents in other tenants.



A production-ready Azure Logic App that automatically synchronizes Microsoft Sentinel security incidents across multiple tenants/workspaces to a centralized Sentinel workspace for unified security operations.[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmurtazaraj786%2FMultiTenant%2Fmain%2Fdeploy.json)



## 🎯 Overview## What It Does



This solution enables Security Operations Centers (SOCs) to aggregate incidents from multiple Microsoft Sentinel instances (e.g., customer workspaces, remote sites) into a single central workspace for:✅ **Triggers** when incident created in source Sentinel  

✅ **Gets** full incident details  

- **Unified Visibility** - See all incidents from multiple tenants in one place✅ **Checks** if already synced (prevents loops)  

- **Centralized Response** - Coordinate security operations across your organization✅ **Creates** incident in ALL target tenants  

- **Multi-Tenant Management** - Manage customer or subsidiary security from one console✅ **Tags** synced incidents with source info  

- **Enhanced Correlation** - Detect cross-tenant attack patterns

## Quick Setup

### Architecture

### 1. Configure Target Tenants

```

┌─────────────────┐Edit `deploy.parameters.json`:

│  AutoLAW        │

│  (Remote)       │──┐```json

└─────────────────┘  │{

                     │  "parameters": {

┌─────────────────┐  │     ┌──────────────────────┐    "targetSubscriptions": {

│  CustomerA      │  ├────►│  Logic App           │      "value": [

│  (Remote)       │──┘     │  (HTTP + Managed ID) │        {

└─────────────────┘        └──────────┬───────────┘          "subscriptionId": "12345678-1234-1234-1234-123456789012",

                                      │          "resourceGroup": "rg-sentinel-target1", 

┌─────────────────┐                   │          "workspace": "sentinel-workspace-1"

│  CustomerN      │                   │        },

│  (Remote)       │───────────────────┘        {

└─────────────────┘                   │          "subscriptionId": "87654321-4321-4321-4321-210987654321",

                                      ▼          "resourceGroup": "rg-sentinel-target2",

                           ┌─────────────────────┐          "workspace": "sentinel-workspace-2" 

                           │  logs-uks-sentinel  │        }

                           │  (Central)          │      ]

                           └─────────────────────┘    }

```  }

}

## ✨ Features```



### Current Features (v1.0)### 2. Deploy

- ✅ **Automatic incident sync** - Runs every 5 minutes (configurable)

- ✅ **Multi-workspace support** - Sync from unlimited remote workspaces**Option A: PowerShell**

- ✅ **Cross-tenant capable** - Works across Azure AD tenants```powershell

- ✅ **Managed Identity authentication** - Secure, passwordless access.\deploy.ps1 -ResourceGroupName "rg-sentinel-source"

- ✅ **Incident metadata** - Title, severity, description, timestamps```

- ✅ **Source tracking** - Tags incidents with source workspace

- ✅ **XDR compatible** - Works with Defender XDR-integrated workspaces**Option B: Azure CLI**

```bash

### Synced Dataaz deployment group create \

Each synced incident includes:  --resource-group "rg-sentinel-source" \

- **Title** - Prefixed with `[SYNCED]` and source workspace  --template-file "deploy.json" \

- **Description** - Original description plus source metadata  --parameters "deploy.parameters.json"

- **Severity** - High/Medium/Low/Informational```

- **Status** - New (all synced incidents start as New)

- **Source Information** - Original workspace, incident number, creation time**Option C: Azure Portal**

- **Timestamps** - Creation time preserved- Click "Deploy to Azure" button above

- Fill in your target subscription details

### Optional Enhancements (See Optimization Guide)

- Entity information (users, IPs, hosts, files)### 3. Authorize Connection

- MITRE ATT&CK tactics

- Alert details and counts1. Go to **Azure Portal** → **Resource Groups** → **Your RG** → **API connections** → **azuresentinel**

- Comments and investigation notes2. Click **Edit API connection** → **Authorize**

- Labels and tags3. Sign in with account that has access to all target subscriptions

- Owner assignment

### 4. Test

## 🚀 Quick Start

Create an incident in your source Sentinel workspace. Check target tenants - you should see `[SYNCED]` incidents appear!

### Prerequisites

- Azure subscription with Contributor access## How It Works

- Microsoft Sentinel workspaces (1 central + 1 or more remote)

- PowerShell 7+ with Az modules (`Az.Accounts`, `Az.Resources`)```

Source Sentinel Incident Created

### Deployment Options         ↓

   Logic App Triggered  

#### Option 1: ARM Template Deployment (Recommended)         ↓

```powershell   Get Full Incident Details

# 1. Login to Azure         ↓

Connect-AzAccount   Check if Already Synced? 

         ↓

# 2. Deploy with automated RBAC assignment   Create in Target Tenant 1

.\Deploy-Final.ps1 -ResourceGroupName "rg-uks-sentinel"   Create in Target Tenant 2  

```   Create in Target Tenant N

         ↓

**That's it!** The script:   Tag with Source Info

- ✅ Deploys the Logic App```

- ✅ Enables Managed Identity

- ✅ Assigns all required RBAC permissions## Files

- ✅ Starts syncing automatically

- `deploy.json` - Main ARM template (WORKS!)

#### Option 2: Azure Portal Code View- `deploy.parameters.json` - Configuration 

For manual deployment or customization:- `deploy.ps1` - Quick deployment script



1. **Create Logic App** (Consumption tier) in Azure Portal## Troubleshooting

2. **Enable System-Assigned Managed Identity**

3. **Copy/paste** `workflow-CODE-VIEW.json` into code view**"Unauthorized"**: Authorize the API connection  

4. **Assign RBAC** using PowerShell commands from `INSTRUCTIONS-FINAL.md`**"Not Found"**: Check subscription/RG/workspace names  

**"No incidents created"**: Check Logic App run history  

## 📋 Configuration

## Requirements

### Workspace Configuration

Edit `deploy-final.parameters.json` to configure your workspaces:- Source tenant: Microsoft Sentinel workspace

- Target tenants: Microsoft Sentinel workspaces  

```json- Cross-tenant permissions (via Azure Lighthouse or direct access)

{- One person/service principal with access to all subscriptions

  "remoteWorkspaces": {

    "value": [That's it! No more complex setup. It just works.
      {
        "name": "AutoLAW",
        "subscriptionId": "your-subscription-id",
        "resourceGroup": "autorg1",
        "workspace": "AutoLAW"
      },
      {
        "name": "CustomerA",
        "subscriptionId": "your-subscription-id",
        "resourceGroup": "rg-uks-sentinel",
        "workspace": "CustomerA"
      }
    ]
  },
  "centralSubscriptionId": {
    "value": "your-subscription-id"
  },
  "centralResourceGroup": {
    "value": "rg-uks-sentinel"
  },
  "centralWorkspace": {
    "value": "logs-uks-sentinel"
  }
}
```

### Sync Frequency
Default: Every 5 minutes

To change:
```json
{
  "recurrenceFrequency": {
    "value": "Minute"  // or "Hour", "Day"
  },
  "recurrenceInterval": {
    "value": 5  // 5 minutes, 1 hour, etc.
  }
}
```

## 🔐 Security & Permissions

### Required RBAC Roles

**On Remote Workspaces** (read access):
- Role: `Microsoft Sentinel Reader`
- Role ID: `8d289c81-5878-46d4-8554-54e1e3d8b5cb`

**On Central Workspace** (write access):
- Role: `Microsoft Sentinel Contributor`
- Role ID: `ab8e14d6-4a74-4a29-9ba8-549422addade`

### Authentication
Uses **Azure Managed Identity** (no passwords, certificates, or secrets required):
- System-assigned identity enabled automatically
- RBAC roles assigned to the identity
- Audience: `https://management.azure.com`

## 📊 Monitoring

### View Sync Activity
1. Open Logic App in Azure Portal
2. Navigate to **Run history**
3. Check each run for:
   - ✅ **Succeeded** - Incidents synced successfully
   - ⚠️ **Failed** - Check error details

### Common Status Codes
- `200 OK` - Successfully retrieved incidents
- `201 Created` - Successfully created incident
- `403 Forbidden` - RBAC permissions missing
- `404 Not Found` - Workspace not found (check configuration)

### Verify Synced Incidents
In your central Sentinel workspace:
```kusto
SecurityIncident
| where Title startswith "[SYNCED]"
| summarize Count=count() by SourceWorkspace=tostring(parse_json(Description).SourceWorkspace)
| order by Count desc
```

## 📁 Files in This Repository

### Deployment Files
| File | Purpose |
|------|---------|
| `deploy-final.json` | ARM template for automated deployment |
| `deploy-final.parameters.json` | Configuration parameters |
| `Deploy-Final.ps1` | PowerShell deployment script with RBAC automation |

### Workflow Files
| File | Purpose |
|------|---------|
| `workflow-CODE-VIEW.json` | Complete workflow for Azure Portal code view |
| `workflow-SIMPLE-CLEAN.json` | Simplified workflow definition only |
| `parameters-values.json` | Parameter values for manual configuration |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | This file - getting started guide |
| `SYNC-OPTIMIZATION-GUIDE.md` | Advanced features and optimization options |
| `XDR-INTEGRATION-IMPACT.md` | XDR integration compatibility guide |
| `INSTRUCTIONS-FINAL.md` | Step-by-step manual deployment guide |

### Reference Files
| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Development guidelines |
| `analytic/*.json` | Sample analytics rules for testing |

## 🔧 Troubleshooting

### No Incidents Syncing

**Problem**: Logic App runs successfully but no incidents appear

**Solutions**:
1. **Check source workspaces have incidents**
   ```kusto
   SecurityIncident
   | where TimeGenerated > ago(1h)
   | count
   ```

2. **Verify RBAC permissions**
   ```powershell
   # Check role assignments on workspace
   Get-AzRoleAssignment -Scope "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{ws}"
   ```

3. **Review run history outputs**
   - Check HTTP GET action - should return incidents
   - Check HTTP PUT action - should get 201 Created

### 403 Forbidden Errors

**Problem**: `"code": "AuthorizationFailed"`

**Solutions**:
1. **Re-run RBAC assignment**
   ```powershell
   .\Deploy-Final.ps1 -ResourceGroupName "rg-uks-sentinel"
   ```

2. **Wait for propagation** (can take 5-10 minutes)

3. **Verify Managed Identity is enabled**
   - Go to Logic App → Identity → System assigned → Status: On

### Duplicate Incidents

**Problem**: Same incidents synced multiple times

**Expected Behavior**: Current version creates duplicates every 5 minutes (by design for simplicity)

**Solutions**:
1. **Add duplicate detection** (see Optimization Guide)
2. **Adjust sync frequency** to hourly instead of 5 minutes
3. **Implement incident tagging** to track already-synced incidents

## 📈 Performance

### Current Capacity
- **API Calls per Run**: ~40 (2 workspaces × 10 incidents × 2 calls each)
- **Frequency**: Every 5 minutes
- **Daily API Calls**: ~11,520
- **Azure Throttling Limit**: 12,000 reads/hour (safe margin)

### Scaling Considerations
- **10 workspaces**: ~200 API calls per run (still safe)
- **20 workspaces**: ~400 API calls per run (consider increasing interval)
- **100+ incidents/workspace**: Consider pagination and filtering

See `SYNC-OPTIMIZATION-GUIDE.md` for performance optimization strategies.

## 🎓 Advanced Usage

### XDR-Integrated Workspaces
✅ **Fully Compatible!** No changes needed.

If your remote workspaces are onboarded to Microsoft Defender XDR:
- Incidents automatically sync from Defender portal to Sentinel workspace
- Logic App reads them via same API
- Provider name changes to "Microsoft XDR"
- Enhanced correlation and richer data included

See `XDR-INTEGRATION-IMPACT.md` for details.

### Adding Entity Sync
To include entity information (users, IPs, hosts):

1. Add HTTP GET action for entities
2. Parse entity response
3. Add to incident description

See `SYNC-OPTIMIZATION-GUIDE.md` Level 2 implementation.

### Cross-Tenant Sync
To sync across different Azure AD tenants:

1. Use **Azure Lighthouse** for delegated access
2. OR use **Service Principal** authentication instead of Managed Identity
3. Configure RBAC in target tenants

## 🤝 Contributing

Found a bug or have an enhancement idea?

1. Check existing issues
2. Create a new issue with details
3. Submit a pull request

## 📄 License

This project is provided as-is for use with Microsoft Sentinel deployments.

## 🆘 Support

### Resources
- [Microsoft Sentinel Documentation](https://learn.microsoft.com/azure/sentinel/)
- [Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)
- [Sentinel REST API Reference](https://learn.microsoft.com/rest/api/securityinsights/)

### Common Issues
See the [Troubleshooting](#-troubleshooting) section above.

## 🗺️ Roadmap

### Planned Enhancements
- [ ] Duplicate detection logic
- [ ] Entity synchronization
- [ ] Bi-directional status updates
- [ ] Comment synchronization
- [ ] Alert relationship preservation
- [ ] Performance metrics dashboard
- [ ] Multi-region support

### Under Consideration
- [ ] Real-time sync (Event Hub trigger)
- [ ] Intelligent filtering (severity-based)
- [ ] Incident enrichment with threat intel
- [ ] Automated response orchestration

## 📝 Changelog

### v1.0.0 (2024-11-06)
- Initial production release
- Multi-workspace incident sync
- Managed Identity authentication
- ARM template deployment
- XDR compatibility
- Comprehensive documentation

---

## 🚀 Get Started Now

```powershell
# Clone the repository
git clone https://github.com/murtazaraj786/MultiTenant.git
cd MultiTenant

# Login to Azure
Connect-AzAccount

# Deploy
.\Deploy-Final.ps1 -ResourceGroupName "rg-uks-sentinel"

# Monitor
# Open Logic App in Azure Portal → Run history
```

**Questions?** Check the documentation files or open an issue!

---

**Built with ❤️ for Security Operations Teams**
