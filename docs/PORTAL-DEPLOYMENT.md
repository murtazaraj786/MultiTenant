# Azure Portal Custom Deployment Guide

This guide shows you how to deploy the Sentinel Multi-Tenant Logic App using the **Azure Portal's Custom Deployment** wizard with an intuitive GUI interface.

## Files for Portal Deployment

- **`portal-deployment.json`** - Main ARM template optimized for Portal UI
- **`createUiDefinition.json`** - Custom UI definition for guided deployment experience

## Deployment Methods

### Method 1: Azure Portal Custom Deployment (Recommended)

This method provides the best GUI experience with auto-populated dropdowns for subscription and resource group.

#### Step 1: Access Custom Deployment

**Option A: Direct Link**
1. Go to Azure Portal: https://portal.azure.com
2. Search for **"Deploy a custom template"** in the top search bar
3. Click **"Deploy a custom template"**

**Option B: Via Create Resource**
1. Azure Portal → **+ Create a resource**
2. Search for **"Template deployment"** or **"Custom deployment"**
3. Click **"Create"** → **"Build your own template in the editor"**

#### Step 2: Load the Template

1. Click **"Build your own template in the editor"**
2. **Delete** the default template content
3. Click **"Load file"**
4. Browse and select: `deployment/arm-templates/portal-deployment.json`
5. Click **"Save"**

#### Step 3: Fill in Deployment Parameters

The Azure Portal will auto-populate these fields:

**Basics Tab:**
- ✅ **Subscription** - Auto-populated dropdown (select your subscription)
- ✅ **Resource Group** - Auto-populated dropdown (select existing or create new)
- **Region** - Select your preferred region (e.g., East US)
- **Logic App Name** - Keep default `sentinel-incident-sync` or customize
- **Location** - Auto-populated from resource group

**Custom Parameters:**
- **Main Tenant ID** - Auto-filled with current tenant ID (or customize)
- **Main Subscription ID** - Auto-filled with selected subscription (or customize)
- **Main Resource Group** - Enter name of RG containing main Sentinel workspace
- **Main Workspace Name** - Enter name of your main Sentinel Log Analytics workspace
- **Recurrence Frequency** - Select from dropdown (Minute, Hour, Day, Week, Month)
- **Recurrence Interval** - Enter number (e.g., 5 for every 5 minutes)
- **Lookback Minutes** - How far back to query incidents (default: 10)
- **Enable Managed Identity** - Leave checked (required)
- **Environment** - Select from dropdown (Development, Test, Staging, Production)

#### Step 4: Review and Deploy

1. Click **"Review + create"**
2. Wait for validation to complete
3. Review all parameters
4. Click **"Create"**

#### Step 5: Monitor Deployment

1. Wait for deployment to complete (usually 2-5 minutes)
2. Click **"Go to resource group"** when complete
3. Find your Logic App resource
4. **IMPORTANT:** Copy the **Managed Identity Principal ID** from deployment outputs

---

### Method 2: Deploy Button (GitHub/Web)

If you're hosting this template on GitHub or a web server, create a "Deploy to Azure" button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYOUR-ORG%2FYOUR-REPO%2Fmain%2Fdeployment%2Farm-templates%2Fportal-deployment.json)

**Markdown for Button:**
```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-RAW-TEMPLATE-URL)
```

**Replace `YOUR-RAW-TEMPLATE-URL` with:**
- URL-encoded path to your `portal-deployment.json`
- Must be publicly accessible (GitHub raw, Azure Blob Storage with SAS, etc.)

---

### Method 3: PowerShell Deployment

If you prefer PowerShell but want to use the GUI-optimized template:

```powershell
# Connect to Azure
Connect-AzAccount

# Set context
Set-AzContext -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Deploy
New-AzResourceGroupDeployment `
    -Name "SentinelMultiTenantSync-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    -ResourceGroupName "sentinel-sync-rg" `
    -TemplateFile "deployment/arm-templates/portal-deployment.json" `
    -logicAppName "sentinel-incident-sync" `
    -mainResourceGroup "sentinel-main-rg" `
    -mainWorkspaceName "main-sentinel-workspace" `
    -Verbose
```

---

## Key Features of Portal Template

### Auto-Populated Fields

✅ **Subscription** - Dropdown shows all your subscriptions
✅ **Resource Group** - Dropdown shows existing RGs + "Create new" option  
✅ **Region** - Dropdown with all Azure regions
✅ **Tenant ID** - Auto-filled with `subscription().tenantId`
✅ **Subscription ID** - Auto-filled with selected subscription

### Smart Defaults

- **Main Tenant ID**: Defaults to current tenant
- **Main Subscription ID**: Defaults to selected subscription
- **Location**: Defaults to resource group location
- **Recurrence**: 5 minutes
- **Lookback**: 10 minutes
- **Managed Identity**: Enabled by default

### Validation

The template includes:
- Parameter validation (min/max values, regex patterns)
- Allowed values for dropdowns
- Required field enforcement
- Descriptive error messages

---

## Post-Deployment Steps

After clicking **"Create"** and deployment completes:

### 1. Get Managed Identity Principal ID

**Via Portal:**
1. Go to deployment outputs
2. Copy the **`managedIdentityPrincipalId`** value

**Via PowerShell:**
```powershell
# Get deployment outputs
$deployment = Get-AzResourceGroupDeployment -ResourceGroupName "sentinel-sync-rg" -Name "YOUR-DEPLOYMENT-NAME"
$principalId = $deployment.Outputs.managedIdentityPrincipalId.Value
Write-Host "Principal ID: $principalId" -ForegroundColor Green

# Save for later use
$principalId | Out-File "managed-identity-principal-id.txt"
```

### 2. Grant RBAC Permissions on Main Sentinel

```powershell
# Assign Microsoft Sentinel Contributor role
New-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName "Microsoft Sentinel Contributor" `
    -Scope "/subscriptions/YOUR-MAIN-SUB-ID/resourceGroups/YOUR-MAIN-RG/providers/Microsoft.OperationalInsights/workspaces/YOUR-MAIN-WORKSPACE"

# Verify assignment
Get-AzRoleAssignment -ObjectId $principalId
```

### 3. Configure Delegated Tenants

**Update the Logic App with your tenant configuration:**

1. Go to Azure Portal → Logic App → **Logic app designer**
2. Find action: **"Get_Delegated_Tenants_Config"**
3. Click to expand
4. Replace the `inputs` JSON with your actual configuration from `config/tenants.json`
5. Click **"Save"**

**Example Configuration:**
```json
{
  "delegatedTenants": [
    {
      "tenantId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "tenantName": "Customer Corp",
      "subscriptionId": "11111111-2222-3333-4444-555555555555",
      "resourceGroup": "customer-sentinel-rg",
      "workspaceName": "customer-workspace",
      "enabled": true
    }
  ],
  "mainTenant": {
    "tenantId": "your-main-tenant-id",
    "subscriptionId": "your-main-sub-id",
    "resourceGroup": "sentinel-main-rg",
    "workspaceName": "main-sentinel-workspace"
  }
}
```

### 4. Deploy Lighthouse Delegation (for cross-tenant access)

For each customer tenant, deploy the Lighthouse delegation:

**In customer tenant:**
```powershell
# Update lighthouse-delegation.parameters.json with Principal ID from Step 1
# Then deploy:
Connect-AzAccount -Tenant "CUSTOMER-TENANT-ID"

New-AzSubscriptionDeployment `
    -Name "SentinelLighthouseDelegation" `
    -Location "eastus" `
    -TemplateFile "deployment/arm-templates/lighthouse-delegation.json" `
    -TemplateParameterFile "deployment/arm-templates/lighthouse-delegation.parameters.json"
```

See **`docs/LIGHTHOUSE-TESTING.md`** for detailed multi-tenant setup instructions.

### 5. Test the Logic App

**Manual Run:**
1. Azure Portal → Logic App → **Overview**
2. Click **"Run Trigger"** → **"Recurrence"**
3. Wait for run to complete
4. Click **"Run history"** to see results

**Check Main Sentinel:**
1. Go to main Sentinel instance → **Incidents**
2. Look for incidents with prefix `[TenantID_IncidentNumber]`
3. Verify incidents were synced successfully

---

## Deployment Outputs

After deployment, you'll see these outputs:

| Output Name | Description | Usage |
|-------------|-------------|-------|
| `logicAppName` | Name of deployed Logic App | Reference for management |
| `logicAppResourceId` | Full resource ID | For ARM templates/scripts |
| `managedIdentityPrincipalId` | **CRITICAL** - Principal ID | Grant RBAC roles, Lighthouse delegation |
| `nextSteps` | Post-deployment checklist | Follow these steps |

---

## Troubleshooting Portal Deployment

### Issue: "Deployment failed - Invalid template"

**Solution:**
- Ensure you copied the entire `portal-deployment.json` content
- Check for any syntax errors if you modified the template
- Use **"Validate"** button before deploying

### Issue: "Parameter validation failed"

**Solution:**
- Check parameter values meet requirements:
  - Logic App name: 1-80 characters, alphanumeric and hyphens only
  - Workspace name: 4-63 characters
  - GUIDs must be valid format
- Fill in all **required** fields

### Issue: "Can't find main Sentinel workspace"

**Cause:** Main workspace doesn't exist or wrong name/RG

**Solution:**
- Verify workspace exists: `Get-AzOperationalInsightsWorkspace`
- Double-check resource group and workspace names
- Ensure Sentinel is enabled on the workspace

### Issue: "Managed identity not showing in outputs"

**Solution:**
- Check deployment completed successfully
- Ensure `enableManagedIdentity` parameter is `true`
- Get it manually:
  ```powershell
  $logicApp = Get-AzLogicApp -ResourceGroupName "RG-NAME" -Name "LOGIC-APP-NAME"
  $logicApp.Identity.PrincipalId
  ```

---

## Comparison: Portal Template vs. Full Template

| Feature | Portal Template | Full Template (logic-app.json) |
|---------|----------------|-------------------------------|
| Auto-populated subscription | ✅ Yes | ❌ Manual |
| Auto-populated RG | ✅ Yes | ❌ Manual |
| Auto-populated tenant ID | ✅ Yes | ❌ Manual |
| Smart defaults | ✅ Optimized | ⚠️ Basic |
| Parameters | Simplified | Full control |
| Use case | Quick deployment, testing | Production, CI/CD |
| PowerShell needed | ❌ Optional | ⚠️ Recommended |

---

## Next Steps

1. ✅ Deploy using Portal Custom Deployment
2. ✅ Copy Managed Identity Principal ID
3. ✅ Grant RBAC permissions
4. ✅ Configure tenant settings in Logic App
5. ✅ Deploy Lighthouse delegations
6. ✅ Test sync manually
7. ✅ Set up monitoring and alerts

**Full Documentation:**
- Multi-tenant setup: `docs/LIGHTHOUSE-TESTING.md`
- Architecture details: `docs/ARCHITECTURE.md`
- Configuration reference: `docs/CONFIGURATION.md`
- Troubleshooting: `docs/TROUBLESHOOTING.md`

---

**Happy Deploying! 🚀**
