# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Microsoft Sentinel Multi-Tenant Incident Synchronization solution.

## Quick Diagnostic Steps

Before diving into specific issues, run these diagnostic commands:

```powershell
# 1. Check Logic App status
Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"

# 2. View recent runs
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -Top 5

# 3. Check for failed runs
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" | 
    Where-Object {$_.Status -eq "Failed"} | Select-Object -First 5

# 4. Get managed identity details
$logicApp = Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"
$logicApp.Identity

# 5. Check role assignments
Get-AzRoleAssignment -ObjectId $logicApp.Identity.PrincipalId
```

## Common Issues and Solutions

### 1. Logic App Not Running

**Symptoms:**
- No runs in run history
- Logic App shows as disabled

**Diagnostics:**
```powershell
$logicApp = Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"
Write-Host "State: $($logicApp.State)"
Write-Host "Provisioning State: $($logicApp.ProvisioningState)"
```

**Solutions:**

**If State = "Disabled":**
```powershell
# Enable the Logic App
Set-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -State "Enabled"
```

**If trigger is not firing:**
- Check trigger configuration in Logic App Designer
- Verify recurrence settings
- Manually trigger: `Start-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -TriggerName "Recurrence"`

---

### 2. Authentication Failures

**Symptoms:**
- Error: "Unauthorized" or "Forbidden"
- Error: "The managed identity is not enabled"
- Error: "Insufficient permissions"

**Diagnostics:**
```powershell
# Check if managed identity is enabled
$logicApp = Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"
if ($logicApp.Identity.Type -eq "None") {
    Write-Host "Managed identity is NOT enabled!" -ForegroundColor Red
} else {
    Write-Host "Managed identity Principal ID: $($logicApp.Identity.PrincipalId)" -ForegroundColor Green
}

# Check role assignments
$roles = Get-AzRoleAssignment -ObjectId $logicApp.Identity.PrincipalId
$roles | Format-Table RoleDefinitionName, Scope
```

**Solutions:**

**Enable Managed Identity:**
```powershell
# This requires redeploying the Logic App with managed identity enabled
# Use the deployment script with -EnableManagedIdentity $true
```

**Grant Missing Permissions:**
```powershell
# On main subscription
New-AzRoleAssignment `
    -ObjectId $logicApp.Identity.PrincipalId `
    -RoleDefinitionName "Microsoft Sentinel Contributor" `
    -Scope "/subscriptions/YOUR-MAIN-SUBSCRIPTION-ID"

# On delegated subscriptions (run for each)
./Grant-Permissions.ps1 `
    -ManagedIdentityPrincipalId $logicApp.Identity.PrincipalId `
    -DelegatedSubscriptionId "CUSTOMER-SUBSCRIPTION-ID" `
    -DelegatedTenantId "CUSTOMER-TENANT-ID"
```

**API Connection Authentication:**
- Go to Azure Portal → Logic App → API Connections
- Select each connection (azuresentinel, azuremonitorlogs)
- Click "Edit API connection"
- Ensure "Authentication Type" is set to "Managed Identity"
- Save and reauthorize if needed

---

### 3. Cannot Query Delegated Workspaces

**Symptoms:**
- Error: "Resource not found"
- Error: "Subscription not found"
- No incidents returned from delegated tenants

**Diagnostics:**
```powershell
# Verify Lighthouse delegations
./Setup-Lighthouse.ps1

# Check if specific subscription is accessible
Get-AzSubscription -SubscriptionId "DELEGATED-SUBSCRIPTION-ID"

# Try to access delegated workspace
$workspace = Get-AzOperationalInsightsWorkspace `
    -ResourceGroupName "customer-rg" `
    -Name "customer-workspace" `
    -SubscriptionId "DELEGATED-SUBSCRIPTION-ID"

if ($workspace) {
    Write-Host "Workspace accessible!" -ForegroundColor Green
} else {
    Write-Host "Cannot access workspace!" -ForegroundColor Red
}
```

**Solutions:**

**Lighthouse Delegation Not Active:**
- Customer must deploy Lighthouse delegation template
- See `docs/DEPLOYMENT.md` → Azure Lighthouse Setup section
- Verify in Azure Portal → Service Providers

**Incorrect Workspace Details:**
- Verify subscription ID, resource group, and workspace name in `config/tenants.json`
- Use Azure Resource Graph to find workspace:
  ```powershell
  Search-AzGraph -Query "Resources | where type == 'microsoft.operationalinsights/workspaces'"
  ```

**Permission Issues:**
- Ensure "Log Analytics Reader" role is assigned on delegated subscription
- Run `Grant-Permissions.ps1` for the delegated tenant

---

### 4. No Incidents Being Created

**Symptoms:**
- Logic App runs successfully
- No errors in run history
- No incidents appear in main Sentinel

**Diagnostics:**
```powershell
# Get detailed run output
$runs = Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -Top 1
$runName = $runs[0].Name

# Get action outputs
Get-AzLogicAppRunAction -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -RunName $runName | 
    Select-Object Name, Status | Format-Table

# Check specific action output
$queryAction = Get-AzLogicAppRunAction -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -RunName $runName `
    -ActionName "Query_Delegated_Sentinel_Incidents"

$queryAction.OutputsLink.Uri  # View full output
```

**Solutions:**

**No Incidents in Source Tenants:**
- Verify delegated tenants have active incidents
- Check severity and status filters in sync settings
- Increase lookback period temporarily to test

**Incidents Filtered Out:**
- Review `config/sync-settings.json` filters
- Temporarily remove filters to test:
  ```json
  "filters": {
    "severity": {
      "include": ["High", "Medium", "Low", "Informational"]
    },
    "status": {
      "include": ["New", "Active", "Closed"]
    }
  }
  ```

**KQL Query Issues:**
- Test KQL query manually in delegated workspace
- Ensure SecurityIncident table exists
- Verify workspace has Sentinel enabled

**Tenant Configuration:**
- Ensure `enabled: true` in tenant config
- Check that tenant IDs and subscription IDs are correct

---

### 5. Duplicate Incidents Created

**Symptoms:**
- Multiple copies of the same incident in main Sentinel
- Incidents re-created on every sync

**Diagnostics:**
```powershell
# Check if deduplication is enabled in config
Get-Content "config/sync-settings.json" | ConvertFrom-Json | Select-Object -ExpandProperty deduplication

# Query main Sentinel for duplicates
# (Run in Log Analytics workspace query editor)
$kql = @"
SecurityIncident
| extend SourceIncidentId = tostring(AdditionalData.sourceIncidentId)
| where isnotempty(SourceIncidentId)
| summarize Count=count() by SourceIncidentId
| where Count > 1
| order by Count desc
"@
```

**Solutions:**

**Enable Deduplication:**
```json
// In config/sync-settings.json
"deduplication": {
  "enabled": true,
  "matchFields": ["sourceIncidentId", "sourceTenantId"]
}
```

**Fix Logic App Deduplication Logic:**
- Ensure `additionalData.sourceIncidentId` is set correctly
- Format: `{tenantId}-{incidentNumber}`
- Verify filter logic in "Filter_Existing_Incident" action

**Clear Duplicates:**
```powershell
# Manual cleanup (use carefully)
# Identify duplicates first, then close older ones
```

---

### 6. API Throttling / Rate Limiting

**Symptoms:**
- Error: "429 Too Many Requests"
- Error: "Request rate exceeded"
- Slow performance or timeouts

**Diagnostics:**
```powershell
# Check concurrent execution settings
# View in Logic App Designer → Settings → Run History

# Monitor API call frequency
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -Top 20 | Measure-Object -Property Duration -Average
```

**Solutions:**

**Reduce Sync Frequency:**
```json
// In logic-app.parameters.json or Logic App Designer
"recurrenceFrequency": "Minute",
"recurrenceInterval": 10  // Change from 5 to 10 minutes
```

**Sequential Processing:**
- Ensure concurrency is set to 1 in "For Each" loops
- Check Logic App Designer → For Each action → Settings → Concurrency Control

**Implement Retry with Backoff:**
- Add retry policy to Sentinel API actions
- Configure in Logic App Designer → Action → Settings → Retry Policy
- Use exponential interval: 30s, 60s, 120s

**Batch Size Limits:**
```json
// In config/sync-settings.json
"performance": {
  "batchSize": 25,  // Reduce from 50
  "parallelTenants": 1,
  "parallelIncidents": 1
}
```

---

### 7. Missing or Incorrect Incident Data

**Symptoms:**
- Incidents synced but fields are empty
- Wrong severity or status
- Missing descriptions or titles

**Diagnostics:**
```powershell
# Check field mappings configuration
Get-Content "config/field-mappings.json" | ConvertFrom-Json

# View incident data in main Sentinel
# Compare with source incident in delegated tenant
```

**Solutions:**

**Review Field Mappings:**
- Verify `config/field-mappings.json` is correct
- Ensure source fields exist in SecurityIncident table
- Test mappings with sample data

**Update Logic App Workflow:**
- Modify "Create_New_Incident" and "Update_Existing_Incident" actions
- Ensure all required fields are mapped
- Check for typos in field names

**Transform Issues:**
- Verify transform functions work correctly
- Test expressions in Logic App Designer → Expression editor

---

### 8. Lighthouse Delegation Issues

**Symptoms:**
- Cannot see delegated subscriptions
- Error: "Tenant not found"
- Delegation appears in portal but not accessible

**Diagnostics:**
```powershell
# List all accessible subscriptions
Get-AzSubscription | Format-Table Name, Id, TenantId

# Check for cross-tenant subscriptions
Get-AzSubscription | Where-Object {$_.TenantId -ne (Get-AzContext).Tenant.Id}

# Verify delegation in customer tenant (customer must run)
Get-AzManagedServicesAssignment
```

**Solutions:**

**Delegation Not Completed:**
- Customer must deploy Lighthouse delegation template
- Verify Principal ID in delegation matches Logic App managed identity
- Check role assignments in delegation (Sentinel Contributor, Log Analytics Reader)

**Delegation Removed:**
- Customer may have removed delegation
- Contact customer to redeploy or verify in their portal

**Wrong Tenant Context:**
```powershell
# Ensure you're in the correct tenant
Get-AzContext
# Should show your service provider tenant
```

**Refresh Delegation:**
- Sometimes takes a few minutes to propagate
- Sign out and sign back in to Azure Portal
- Run: `Clear-AzContext -Force; Connect-AzAccount`

---

### 9. Performance Issues

**Symptoms:**
- Logic App runs take a long time
- Timeouts
- High costs

**Diagnostics:**
```powershell
# Analyze run durations
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -Top 20 | 
    Select-Object StartTime, EndTime, @{Name="Duration";Expression={$_.EndTime - $_.StartTime}} |
    Measure-Object -Property Duration -Average -Maximum

# Check action execution times in portal
# Azure Portal → Logic App → Run History → Select run → View details
```

**Solutions:**

**Optimize KQL Queries:**
```kql
// Add more specific filters
SecurityIncident
| where TimeGenerated > ago(5m)  // Narrow time range
| where Status in ('New', 'Active')  // Filter early
| where Severity in ('High', 'Medium')  // Filter by severity
| project IncidentNumber, Title, Severity, Status, CreatedTime, Description  // Only needed columns
| take 100  // Limit results
```

**Reduce Lookback Period:**
```json
"lookbackPeriod": {
  "minutes": 5  // Reduce from 10 to 5
}
```

**Increase Sync Interval:**
```json
"syncSettings": {
  "frequency": {
    "interval": 10  // Run every 10 minutes instead of 5
  }
}
```

**Use Logic App Standard:**
- Migrate to Logic App Standard for better performance
- Dedicated resources vs. consumption plan

---

### 10. Configuration Issues

**Symptoms:**
- Error: "Cannot parse JSON"
- Config not loading
- Unexpected behavior

**Diagnostics:**
```powershell
# Validate JSON files
Get-Content "config/tenants.json" | ConvertFrom-Json
Get-Content "config/sync-settings.json" | ConvertFrom-Json
Get-Content "config/field-mappings.json" | ConvertFrom-Json

# If error, check JSON syntax
```

**Solutions:**

**JSON Syntax Errors:**
- Use JSON validator: https://jsonlint.com
- Check for missing commas, brackets
- Ensure proper escaping of special characters

**Load from Key Vault (Recommended):**
```powershell
# Store config in Key Vault
$config = Get-Content "config/tenants.json" -Raw
$secretValue = ConvertTo-SecureString $config -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "sentinel-sync-kv" -Name "TenantConfig" -SecretValue $secretValue

# Update Logic App to read from Key Vault
# Add "Get secret" action in Logic App Designer
```

---

## Advanced Diagnostics

### Enable Detailed Logging

1. **Add Compose Actions:**
   - In Logic App Designer, add "Compose" actions to log intermediate values
   - Example: Log query results, incident data, etc.

2. **Use Application Insights:**
   ```powershell
   # Create Application Insights
   New-AzApplicationInsights -ResourceGroupName "sentinel-sync-rg" `
       -Name "sentinel-sync-insights" `
       -Location "eastus"
   
   # Link to Logic App (requires Logic App Standard)
   ```

3. **Azure Monitor Logs:**
   ```powershell
   # Enable diagnostic settings
   # Azure Portal → Logic App → Diagnostic settings → Add diagnostic setting
   # Send to Log Analytics workspace
   ```

### Analyzing Run History Programmatically

```powershell
# Get detailed run information
$runs = Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -Top 50

# Analyze success rate
$successRate = ($runs | Where-Object {$_.Status -eq "Succeeded"}).Count / $runs.Count * 100
Write-Host "Success Rate: $successRate%"

# Find common errors
$errors = $runs | Where-Object {$_.Status -eq "Failed"} | ForEach-Object {
    $runName = $_.Name
    $actions = Get-AzLogicAppRunAction -ResourceGroupName "sentinel-sync-rg" `
        -Name "sentinel-incident-sync" `
        -RunName $runName
    $actions | Where-Object {$_.Status -eq "Failed"}
}

$errors | Group-Object ActionName | Sort-Object Count -Descending
```

### Test Individual Components

**Test KQL Query:**
```kql
// Run in delegated workspace
SecurityIncident
| where TimeGenerated > ago(1h)
| where Status in ('New', 'Active')
| project IncidentNumber, Title, Severity, Status, CreatedTime
```

**Test Sentinel API:**
```powershell
# Get access token
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/").Token

# List incidents
$subscriptionId = "YOUR-SUBSCRIPTION-ID"
$resourceGroup = "YOUR-RG"
$workspaceName = "YOUR-WORKSPACE"

$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/providers/Microsoft.SecurityInsights/incidents?api-version=2021-10-01"

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$response.value | Format-Table name, properties.title, properties.severity
```

## Getting Help

### Check Documentation
- Review `README.md` for overview
- Review `docs/ARCHITECTURE.md` for design details
- Review `docs/DEPLOYMENT.md` for setup steps

### Azure Support Resources
- [Azure Logic Apps Troubleshooting](https://docs.microsoft.com/azure/logic-apps/logic-apps-diagnosing-failures)
- [Azure Lighthouse Troubleshooting](https://docs.microsoft.com/azure/lighthouse/how-to/view-manage-service-providers)
- [Microsoft Sentinel Documentation](https://docs.microsoft.com/azure/sentinel/)

### Community Resources
- [Microsoft Tech Community - Sentinel](https://techcommunity.microsoft.com/t5/microsoft-sentinel/bd-p/MicrosoftSentinel)
- [Stack Overflow - azure-logic-apps](https://stackoverflow.com/questions/tagged/azure-logic-apps)

### Collect Information for Support

If you need to open a support case, collect:

```powershell
# 1. Logic App details
Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" | ConvertTo-Json -Depth 10 > logicapp-details.json

# 2. Recent run history
Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -Top 10 | ConvertTo-Json > run-history.json

# 3. Failed run details
$failedRun = Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" | Where-Object {$_.Status -eq "Failed"} | Select-Object -First 1
Get-AzLogicAppRunAction -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -RunName $failedRun.Name | ConvertTo-Json -Depth 10 > failed-run-details.json

# 4. Role assignments
Get-AzRoleAssignment -ObjectId $logicApp.Identity.PrincipalId | ConvertTo-Json > role-assignments.json
```

---

**Last Updated:** November 2025  
**Version:** 1.0.0
