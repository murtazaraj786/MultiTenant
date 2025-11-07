# Multi-Tenant Sentinel Incident Sync - Configuration Guide

## 📋 How to Configure for Your Environment

### Step 1: Update Placeholders

Replace these placeholders with your actual Azure resource information:

#### Remote Workspaces (sources to sync FROM)
- `REMOTE_WORKSPACE_1_NAME` → Display name (e.g., "Production SOC")
- `YOUR_REMOTE_WORKSPACE_1_SUBSCRIPTION_ID` → Azure subscription ID
- `YOUR_REMOTE_WORKSPACE_1_RESOURCE_GROUP` → Resource group name
- `YOUR_REMOTE_WORKSPACE_1_NAME` → Actual workspace name

#### Central Workspace (target to sync TO)
- `YOUR_CENTRAL_SUBSCRIPTION_ID` → Central subscription ID
- `YOUR_CENTRAL_RESOURCE_GROUP` → Central resource group
- `YOUR_CENTRAL_WORKSPACE_NAME` → Central workspace name

### Step 2: Add/Remove Workspaces

**To add more remote workspaces:**
Copy this block and update the placeholders:
```json
{
  "name": "ADDITIONAL_WORKSPACE_NAME",
  "subscriptionId": "ADDITIONAL_SUBSCRIPTION_ID", 
  "resourceGroup": "ADDITIONAL_RESOURCE_GROUP",
  "workspace": "ADDITIONAL_WORKSPACE_NAME"
}
```

**To remove a workspace:**
Delete the entire workspace block (including the braces and comma).

### Step 3: Files to Update

1. **ARM Template Parameters:** `Deploy\deploy-final.parameters(cyberdev).json`
2. **Workflow File:** `workflow-latest.json`

### Step 4: Deploy

Choose your deployment method:
- **ARM Template:** Use `Deploy\Deploy-Final.ps1`
- **Manual:** Copy `workflow-latest.json` content to Logic App Code View

## 🎯 Example Configuration

```json
"remoteWorkspaces": {
  "value": [
    {
      "name": "Production SOC",
      "subscriptionId": "12345678-1234-1234-1234-123456789012",
      "resourceGroup": "rg-prod-security",
      "workspace": "sentinel-prod"
    },
    {
      "name": "Development SOC",
      "subscriptionId": "87654321-4321-4321-4321-210987654321",
      "resourceGroup": "rg-dev-security", 
      "workspace": "sentinel-dev"
    }
  ]
},
"centralSubscriptionId": {
  "value": "11111111-2222-3333-4444-555555555555"
},
"centralResourceGroup": {
  "value": "rg-central-soc"
},
"centralWorkspace": {
  "value": "sentinel-central"
}
```

## ✅ Ready to Deploy!

After updating the placeholders, your Logic App will sync incidents from all remote workspaces to your central workspace every 5 minutes.