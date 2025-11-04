# Deployment Guide

This guide provides step-by-step instructions for deploying the Microsoft Sentinel Multi-Tenant Incident Synchronization solution.

## Prerequisites

### Azure Subscriptions

- **Main Tenant**: Azure subscription with Microsoft Sentinel deployed
- **Delegated Tenants**: Customer tenants with Azure Lighthouse delegations configured

### Required Tools

- **PowerShell**: Version 7.0 or later recommended
- **Azure PowerShell Module**: Az.Accounts, Az.Resources, Az.LogicApp
- **Permissions**: 
  - Owner or Contributor on main subscription
  - User Access Administrator to assign RBAC roles

### Azure Lighthouse Setup

Customers must delegate their subscriptions to your service provider tenant. See [Azure Lighthouse Setup](#azure-lighthouse-setup) section below.

## Installation Steps

### Step 1: Install Azure PowerShell

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force

# Verify installation
Get-Module -ListAvailable -Name Az
```

### Step 2: Clone or Download the Solution

```powershell
# If using Git
git clone <repository-url>
cd MultiTenant

# Or download and extract the ZIP file
```

### Step 3: Configure Parameters

Edit `deployment/arm-templates/logic-app.parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "logicAppName": {
      "value": "sentinel-incident-sync"
    },
    "location": {
      "value": "eastus"
    },
    "mainTenantId": {
      "value": "YOUR-TENANT-ID"
    },
    "mainSubscriptionId": {
      "value": "YOUR-SUBSCRIPTION-ID"
    },
    "mainResourceGroup": {
      "value": "sentinel-main-rg"
    },
    "mainWorkspaceName": {
      "value": "your-sentinel-workspace"
    }
  }
}
```

### Step 4: Deploy the Solution

```powershell
# Navigate to scripts directory
cd deployment/scripts

# Connect to Azure
Connect-AzAccount

# Run deployment script
./Deploy-Solution.ps1 `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID" `
    -ResourceGroupName "sentinel-sync-rg" `
    -Location "eastus" `
    -LogicAppName "sentinel-incident-sync" `
    -MainTenantId "YOUR-TENANT-ID" `
    -MainSubscriptionId "YOUR-SUBSCRIPTION-ID" `
    -MainResourceGroup "sentinel-main-rg" `
    -MainWorkspaceName "your-sentinel-workspace"
```

**Expected Output:**
```
=====================================
Sentinel Multi-Tenant Sync Deployment
=====================================

[1/8] Checking Azure PowerShell module...
[2/8] Connecting to Azure...
[3/8] Setting subscription context...
Using subscription: xxx-xxx-xxx
[4/8] Creating resource group...
Created resource group: sentinel-sync-rg
[5/8] Preparing deployment parameters...
[6/8] Deploying Logic App...
Logic App deployed successfully!
  Logic App ID: /subscriptions/.../Microsoft.Logic/workflows/sentinel-incident-sync
  Managed Identity Principal ID: xxx-xxx-xxx
[7/8] Assigning permissions to managed identity...
  Assigning 'Microsoft Sentinel Contributor' role...
  Permissions assigned successfully!
[8/8] Deployment Complete!
```

### Step 5: Configure Tenant List

Edit `config/tenants.json` with your delegated tenant details:

```json
{
  "delegatedTenants": [
    {
      "tenantId": "customer-tenant-id",
      "tenantName": "Customer Name",
      "subscriptionId": "customer-subscription-id",
      "resourceGroup": "customer-sentinel-rg",
      "workspaceName": "customer-sentinel-workspace",
      "enabled": true,
      "description": "Production customer",
      "tags": {
        "customer": "CustomerName",
        "environment": "production"
      }
    }
  ]
}
```

**Finding Your Delegated Tenants:**

```powershell
# Run the Lighthouse discovery script
cd deployment/scripts
./Setup-Lighthouse.ps1

# This will:
# 1. List all accessible subscriptions
# 2. Identify delegated subscriptions
# 3. Export to config/discovered-tenants.json
```

### Step 6: Grant Permissions on Delegated Subscriptions

For each delegated customer tenant, grant the Logic App managed identity the required permissions:

```powershell
# Get the managed identity principal ID from deployment output
$managedIdentityId = "xxx-xxx-xxx"  # From Step 4 output

# For each delegated tenant
./Grant-Permissions.ps1 `
    -ManagedIdentityPrincipalId $managedIdentityId `
    -DelegatedSubscriptionId "customer-subscription-id" `
    -DelegatedTenantId "customer-tenant-id"
```

**Required Roles:**
- Microsoft Sentinel Contributor
- Log Analytics Reader

### Step 7: Update Logic App with Tenant Configuration

**Option A: Manual Configuration (Testing)**

For testing, you can hard-code tenant configuration in the Logic App:

1. Open Logic App in Azure Portal
2. Go to Logic App Designer
3. Find the "Get_Delegated_Tenants_Config" action
4. Update the JSON with your tenant list

**Option B: Secure Configuration (Production)**

For production, store configuration in Azure Key Vault or Storage Account:

1. **Create Key Vault:**
   ```powershell
   New-AzKeyVault -Name "sentinel-sync-kv" -ResourceGroupName "sentinel-sync-rg" -Location "eastus"
   ```

2. **Store Configuration:**
   ```powershell
   $tenantsJson = Get-Content "../../config/tenants.json" -Raw
   $secretValue = ConvertTo-SecureString $tenantsJson -AsPlainText -Force
   Set-AzKeyVaultSecret -VaultName "sentinel-sync-kv" -Name "TenantConfiguration" -SecretValue $secretValue
   ```

3. **Grant Logic App Access:**
   ```powershell
   Set-AzKeyVaultAccessPolicy -VaultName "sentinel-sync-kv" `
       -ObjectId $managedIdentityId `
       -PermissionsToSecrets Get
   ```

4. **Update Logic App to Read from Key Vault** (modify workflow definition)

### Step 8: Test the Deployment

```powershell
# Trigger a manual run
Start-AzLogicApp -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -TriggerName "Recurrence"

# Check run status
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" | Select-Object -First 1

# View detailed run
$runName = (Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" | Select-Object -First 1).Name
Get-AzLogicAppRunAction -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -RunName $runName
```

### Step 9: Verify Synchronization

1. **Check Main Sentinel Instance:**
   - Navigate to Microsoft Sentinel in Azure Portal
   - Go to Incidents
   - Look for incidents with tenant prefix in title
   - Verify incidents have source tenant tags

2. **Check Logic App Logs:**
   ```powershell
   # Get recent runs
   Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" `
       -Name "sentinel-incident-sync" `
       -Top 10 | Format-Table Status, StartTime, EndTime
   
   # Check for errors
   Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" `
       -Name "sentinel-incident-sync" | 
       Where-Object {$_.Status -eq "Failed"}
   ```

### Step 10: Configure Monitoring

Set up Azure Monitor alerts for Logic App failures:

```powershell
# Create action group for notifications
$actionGroup = New-AzActionGroup -Name "SentinelSyncAlerts" `
    -ResourceGroupName "sentinel-sync-rg" `
    -ShortName "SyncAlert" `
    -EmailReceiver -Name "SOC Team" -EmailAddress "soc@company.com"

# Create alert rule for failed runs
$condition = New-AzMetricAlertRuleV2Criteria -MetricName "RunsFailed" `
    -TimeAggregation Total -Operator GreaterThan -Threshold 0

New-AzMetricAlertRuleV2 -Name "LogicAppFailureAlert" `
    -ResourceGroupName "sentinel-sync-rg" `
    -WindowSize 00:05:00 `
    -Frequency 00:05:00 `
    -TargetResourceId "/subscriptions/.../Microsoft.Logic/workflows/sentinel-incident-sync" `
    -Condition $condition `
    -ActionGroupId $actionGroup.Id `
    -Severity 2
```

## Azure Lighthouse Setup

### Customer Responsibilities

Customers must delegate their Azure subscriptions to your service provider tenant using Azure Lighthouse.

**Delegation Template:**

Create `lighthouse-delegation.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "mspOfferName": {
      "type": "string",
      "defaultValue": "Sentinel Multi-Tenant Incident Management"
    },
    "mspOfferDescription": {
      "type": "string",
      "defaultValue": "Enables cross-tenant security incident monitoring and response"
    },
    "managedByTenantId": {
      "type": "string",
      "metadata": {
        "description": "Your service provider tenant ID"
      }
    },
    "authorizations": {
      "type": "array",
      "defaultValue": [
        {
          "principalId": "YOUR-MANAGED-IDENTITY-PRINCIPAL-ID",
          "roleDefinitionId": "ab8e14d6-4a74-4a29-9ba8-549422addade",
          "principalIdDisplayName": "Sentinel Sync Logic App"
        },
        {
          "principalId": "YOUR-MANAGED-IDENTITY-PRINCIPAL-ID",
          "roleDefinitionId": "73c42c96-874c-492b-b04d-ab87d138a893",
          "principalIdDisplayName": "Sentinel Sync Logic App"
        }
      ]
    }
  },
  "variables": {
    "mspRegistrationName": "[guid(parameters('mspOfferName'))]",
    "mspAssignmentName": "[guid(parameters('mspOfferName'))]"
  },
  "resources": [
    {
      "type": "Microsoft.ManagedServices/registrationDefinitions",
      "apiVersion": "2020-02-01-preview",
      "name": "[variables('mspRegistrationName')]",
      "properties": {
        "registrationDefinitionName": "[parameters('mspOfferName')]",
        "description": "[parameters('mspOfferDescription')]",
        "managedByTenantId": "[parameters('managedByTenantId')]",
        "authorizations": "[parameters('authorizations')]"
      }
    },
    {
      "type": "Microsoft.ManagedServices/registrationAssignments",
      "apiVersion": "2020-02-01-preview",
      "name": "[variables('mspAssignmentName')]",
      "dependsOn": [
        "[resourceId('Microsoft.ManagedServices/registrationDefinitions/', variables('mspRegistrationName'))]"
      ],
      "properties": {
        "registrationDefinitionId": "[resourceId('Microsoft.ManagedServices/registrationDefinitions/', variables('mspRegistrationName'))]"
      }
    }
  ]
}
```

**Role Definition IDs:**
- `ab8e14d6-4a74-4a29-9ba8-549422addade` = Microsoft Sentinel Contributor
- `73c42c96-874c-492b-b04d-ab87d138a893` = Log Analytics Reader

**Customer Deployment:**

```powershell
# Customer runs this in their tenant/subscription
New-AzSubscriptionDeployment `
    -Name "SentinelLighthouseDelegation" `
    -Location "eastus" `
    -TemplateFile "lighthouse-delegation.json" `
    -managedByTenantId "YOUR-SERVICE-PROVIDER-TENANT-ID"
```

## Post-Deployment Configuration

### Customize Sync Settings

Edit `config/sync-settings.json` to adjust:

```json
{
  "syncSettings": {
    "frequency": {
      "interval": 5,
      "type": "Minute"
    },
    "lookbackPeriod": {
      "minutes": 10
    }
  },
  "filters": {
    "severity": {
      "include": ["High", "Medium"]
    },
    "status": {
      "include": ["New", "Active"]
    }
  }
}
```

### Update Field Mappings

Customize `config/field-mappings.json` to control which fields are synchronized and how they're transformed.

## Troubleshooting Deployment

### Common Issues

**Issue: "Permission denied" when deploying**
```
Solution: Ensure you have Contributor role on the subscription
```

**Issue: "Managed identity not found"**
```
Solution: Wait 60 seconds after deployment for identity propagation
```

**Issue: "Cannot query delegated workspace"**
```
Solution: Verify Lighthouse delegation is active and permissions are granted
```

### Verification Commands

```powershell
# Verify resource group
Get-AzResourceGroup -Name "sentinel-sync-rg"

# Verify Logic App
Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"

# Verify managed identity
$logicApp = Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"
$logicApp.Identity

# Verify role assignments
Get-AzRoleAssignment -ObjectId $logicApp.Identity.PrincipalId
```

## Uninstall

To remove the solution:

```powershell
# Remove resource group (includes Logic App and connections)
Remove-AzResourceGroup -Name "sentinel-sync-rg" -Force

# Remove role assignments (if needed)
$roleAssignments = Get-AzRoleAssignment -ObjectId $managedIdentityId
$roleAssignments | ForEach-Object {
    Remove-AzRoleAssignment -ObjectId $_.ObjectId -RoleDefinitionName $_.RoleDefinitionName -Scope $_.Scope
}
```

## Next Steps

After successful deployment:

1. ✅ Review `docs/CONFIGURATION.md` for advanced configuration options
2. ✅ Set up monitoring and alerting
3. ✅ Test with a single tenant before enabling all tenants
4. ✅ Document your specific tenant configurations
5. ✅ Schedule regular reviews of Lighthouse delegations

## Support Resources

- [Azure Logic Apps Documentation](https://docs.microsoft.com/azure/logic-apps/)
- [Azure Lighthouse Documentation](https://docs.microsoft.com/azure/lighthouse/)
- [Microsoft Sentinel Documentation](https://docs.microsoft.com/azure/sentinel/)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
