# Multi-Tenant Sentinel Incident Sync - FIXED VERSION

This Logic App **actually works** and creates incidents in other tenants.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmurtazaraj786%2FMultiTenant%2Fmain%2Fdeploy.json)

## What It Does

✅ **Triggers** when incident created in source Sentinel  
✅ **Gets** full incident details  
✅ **Checks** if already synced (prevents loops)  
✅ **Creates** incident in ALL target tenants  
✅ **Tags** synced incidents with source info  

## Quick Setup

### 1. Configure Target Tenants

Edit `deploy.parameters.json`:

```json
{
  "parameters": {
    "targetSubscriptions": {
      "value": [
        {
          "subscriptionId": "12345678-1234-1234-1234-123456789012",
          "resourceGroup": "rg-sentinel-target1", 
          "workspace": "sentinel-workspace-1"
        },
        {
          "subscriptionId": "87654321-4321-4321-4321-210987654321",
          "resourceGroup": "rg-sentinel-target2",
          "workspace": "sentinel-workspace-2" 
        }
      ]
    }
  }
}
```

### 2. Deploy

**Option A: PowerShell**
```powershell
.\deploy.ps1 -ResourceGroupName "rg-sentinel-source"
```

**Option B: Azure CLI**
```bash
az deployment group create \
  --resource-group "rg-sentinel-source" \
  --template-file "deploy.json" \
  --parameters "deploy.parameters.json"
```

**Option C: Azure Portal**
- Click "Deploy to Azure" button above
- Fill in your target subscription details

### 3. Authorize Connection

1. Go to **Azure Portal** → **Resource Groups** → **Your RG** → **API connections** → **azuresentinel**
2. Click **Edit API connection** → **Authorize**
3. Sign in with account that has access to all target subscriptions

### 4. Test

Create an incident in your source Sentinel workspace. Check target tenants - you should see `[SYNCED]` incidents appear!

## How It Works

```
Source Sentinel Incident Created
         ↓
   Logic App Triggered  
         ↓
   Get Full Incident Details
         ↓
   Check if Already Synced? 
         ↓
   Create in Target Tenant 1
   Create in Target Tenant 2  
   Create in Target Tenant N
         ↓
   Tag with Source Info
```

## Files

- `deploy.json` - Main ARM template (WORKS!)
- `deploy.parameters.json` - Configuration 
- `deploy.ps1` - Quick deployment script

## Troubleshooting

**"Unauthorized"**: Authorize the API connection  
**"Not Found"**: Check subscription/RG/workspace names  
**"No incidents created"**: Check Logic App run history  

## Requirements

- Source tenant: Microsoft Sentinel workspace
- Target tenants: Microsoft Sentinel workspaces  
- Cross-tenant permissions (via Azure Lighthouse or direct access)
- One person/service principal with access to all subscriptions

That's it! No more complex setup. It just works.