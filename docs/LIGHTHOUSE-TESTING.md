# Multi-Tenant Lighthouse Testing Guide

This guide walks you through testing the Sentinel Multi-Tenant solution with **real Azure Lighthouse** delegations across multiple tenants.

## Prerequisites

### Required Tenants

You need access to at least **2 Azure AD tenants**:

1. **Service Provider Tenant** - Where Logic App runs (your main tenant)
2. **Customer Tenant(s)** - Where source Sentinel instances are (1 or more test tenants)

### Getting Test Tenants

**Option 1: Use Existing Tenants**
- Your organization's main tenant
- Development/sandbox tenants
- Partner/customer test tenants

**Option 2: Create Free Tenants**
- Create new Azure AD directory: Portal → Azure Active Directory → Manage tenants → Create
- Start free trial for Azure subscription in new tenant
- Free tier includes enough for testing

**Option 3: Microsoft 365 Developer Program** (Free)
- Sign up: https://developer.microsoft.com/microsoft-365/dev-program
- Get instant E5 sandbox with Azure AD tenant
- Add Azure subscription to this tenant

## Step-by-Step Setup

### Phase 1: Deploy Service Provider Components

**In your main/service provider tenant:**

#### 1.1. Deploy Logic App

```powershell
# Connect to service provider tenant
Connect-AzAccount -Tenant "YOUR-SERVICE-PROVIDER-TENANT-ID"

# Navigate to deployment scripts
cd "deployment/scripts"

# Deploy the Logic App
./Deploy-Solution.ps1 `
    -SubscriptionId "YOUR-MAIN-SUBSCRIPTION-ID" `
    -ResourceGroupName "sentinel-sync-rg" `
    -Location "eastus" `
    -LogicAppName "sentinel-incident-sync" `
    -MainTenantId "YOUR-SERVICE-PROVIDER-TENANT-ID" `
    -MainSubscriptionId "YOUR-MAIN-SUBSCRIPTION-ID" `
    -MainResourceGroup "sentinel-main-rg" `
    -MainWorkspaceName "main-sentinel-workspace"
```

#### 1.2. Get Managed Identity Principal ID

**Save this - you'll need it for Lighthouse delegation!**

```powershell
$logicApp = Get-AzLogicApp -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync"
$principalId = $logicApp.Identity.PrincipalId
Write-Host "Managed Identity Principal ID: $principalId" -ForegroundColor Green

# Save this value!
$principalId | Out-File "managed-identity-principal-id.txt"
```

#### 1.3. Deploy Main Sentinel Instance

If you don't have one already:
- Azure Portal → Create Microsoft Sentinel
- Select or create Log Analytics workspace
- Enable Sentinel

---

### Phase 2: Deploy Customer Components

**Repeat for each customer/test tenant:**

#### 2.1. Switch to Customer Tenant

```powershell
# Sign out and sign in to customer tenant
Disconnect-AzAccount
Connect-AzAccount -Tenant "CUSTOMER-TENANT-ID"
```

#### 2.2. Create Customer Resources

```powershell
# Set subscription context
Set-AzContext -SubscriptionId "CUSTOMER-SUBSCRIPTION-ID"

# Create resource group
New-AzResourceGroup -Name "customer-sentinel-rg" -Location "eastus"

# Create Log Analytics Workspace
New-AzOperationalInsightsWorkspace `
    -ResourceGroupName "customer-sentinel-rg" `
    -Name "customer-sentinel-workspace" `
    -Location "eastus" `
    -Sku "PerGB2018"
```

#### 2.3. Enable Sentinel

Via Azure Portal (must be done manually):
1. Go to **Microsoft Sentinel** → **Create**
2. Select the workspace you just created: `customer-sentinel-workspace`
3. Click **Add**

#### 2.4. Create Test Incidents

Generate some test incidents:

**Option A: Use Analytics Rules**
- In Sentinel, create detection rules that will trigger
- Wait for them to create incidents

**Option B: Manually Create Test Incident (for quick testing)**

Via Azure Portal:
1. Go to Sentinel → Incidents
2. Click **+ Create incident**
3. Fill in details (Title, Severity, Status, etc.)
4. Save

**Option C: Via API (PowerShell)**

```powershell
# This requires proper API access - simpler to use Portal for testing
```

---

### Phase 3: Configure Lighthouse Delegation

**Still in customer tenant:**

#### 3.1. Update Lighthouse Template Parameters

Edit `lighthouse-delegation.parameters.json`:

```json
{
  "managedByTenantId": {
    "value": "YOUR-SERVICE-PROVIDER-TENANT-ID"
  },
  "managedIdentityPrincipalId": {
    "value": "PRINCIPAL-ID-FROM-STEP-1.2"
  }
}
```

#### 3.2. Deploy Lighthouse Delegation

**Customer must deploy this in their subscription:**

```powershell
# Make sure you're in customer tenant
Connect-AzAccount -Tenant "CUSTOMER-TENANT-ID"

# Deploy at subscription scope
New-AzSubscriptionDeployment `
    -Name "SentinelLighthouseDelegation" `
    -Location "eastus" `
    -TemplateFile "../../deployment/arm-templates/lighthouse-delegation.json" `
    -TemplateParameterFile "../../deployment/arm-templates/lighthouse-delegation.parameters.json" `
    -Verbose
```

#### 3.3. Verify Delegation

**In customer tenant:**

```powershell
# Check delegations
Get-AzManagedServicesAssignment | Format-List

# Check the definition
Get-AzManagedServicesDefinition | Format-List
```

**In service provider tenant:**

```powershell
# Switch back to service provider tenant
Connect-AzAccount -Tenant "YOUR-SERVICE-PROVIDER-TENANT-ID"

# You should now see the customer subscription
Get-AzSubscription | Where-Object {$_.TenantId -ne (Get-AzContext).Tenant.Id}

# Verify you can access customer resources
$workspace = Get-AzOperationalInsightsWorkspace `
    -ResourceGroupName "customer-sentinel-rg" `
    -Name "customer-sentinel-workspace" `
    -SubscriptionId "CUSTOMER-SUBSCRIPTION-ID"

Write-Host "Successfully accessed customer workspace!" -ForegroundColor Green
```

---

### Phase 4: Configure and Test Sync

**Back in service provider tenant:**

#### 4.1. Update Tenant Configuration

Edit `config/tenants.json`:

```json
{
  "delegatedTenants": [
    {
      "tenantId": "CUSTOMER-TENANT-ID-1",
      "tenantName": "Test Customer 1",
      "subscriptionId": "CUSTOMER-SUBSCRIPTION-ID-1",
      "resourceGroup": "customer-sentinel-rg",
      "workspaceName": "customer-sentinel-workspace",
      "enabled": true,
      "description": "Test customer for Lighthouse validation",
      "tags": {
        "environment": "test",
        "customer": "TestCustomer1"
      }
    }
  ],
  "mainTenant": {
    "tenantId": "YOUR-SERVICE-PROVIDER-TENANT-ID",
    "subscriptionId": "YOUR-MAIN-SUBSCRIPTION-ID",
    "resourceGroup": "sentinel-main-rg",
    "workspaceName": "main-sentinel-workspace"
  }
}
```

#### 4.2. Update Logic App Configuration

**Option A: Hard-code for testing** (quick but not recommended for production)

1. Go to Azure Portal → Logic App → Logic App Designer
2. Find action: `Get_Delegated_Tenants_Config`
3. Replace the Compose action input with your `tenants.json` content
4. Save

**Option B: Load from Azure Key Vault** (recommended)

```powershell
# Create Key Vault
New-AzKeyVault `
    -Name "sentinel-sync-kv-test" `
    -ResourceGroupName "sentinel-sync-rg" `
    -Location "eastus"

# Store tenant config
$tenantsJson = Get-Content "../../config/tenants.json" -Raw
$secretValue = ConvertTo-SecureString $tenantsJson -AsPlainText -Force
Set-AzKeyVaultSecret `
    -VaultName "sentinel-sync-kv-test" `
    -Name "TenantConfiguration" `
    -SecretValue $secretValue

# Grant Logic App access to Key Vault
Set-AzKeyVaultAccessPolicy `
    -VaultName "sentinel-sync-kv-test" `
    -ObjectId $principalId `
    -PermissionsToSecrets Get

# Update Logic App to read from Key Vault
# (Modify the "Get_Delegated_Tenants_Config" action in Designer)
```

#### 4.3. Run Manual Test

```powershell
# Trigger Logic App manually
Start-AzLogicApp `
    -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -TriggerName "Recurrence"

# Wait a few seconds, then check run history
Get-AzLogicAppRunHistory `
    -ResourceGroupName "sentinel-sync-rg" `
    -Name "sentinel-incident-sync" `
    -Top 1 | Format-List

# Check if successful
$lastRun = Get-AzLogicAppRunHistory -ResourceGroupName "sentinel-sync-rg" -Name "sentinel-incident-sync" -Top 1
if ($lastRun.Status -eq "Succeeded") {
    Write-Host "✅ Sync successful!" -ForegroundColor Green
} else {
    Write-Host "❌ Sync failed. Check run details in Azure Portal." -ForegroundColor Red
}
```

#### 4.4. Verify Incidents Synced

Check main Sentinel instance:

```powershell
# Via Portal
# Go to Microsoft Sentinel → Incidents
# Look for incidents with tenant ID prefix

# Via KQL (in Log Analytics)
# Run in main workspace:
```

```kql
SecurityIncident
| where Title contains "CUSTOMER-TENANT-ID"
| project TimeGenerated, Title, Severity, Status
| order by TimeGenerated desc
```

---

## Verification Checklist

### ✅ Service Provider Tenant
- [ ] Logic App deployed
- [ ] Main Sentinel instance has workspace
- [ ] Managed identity principal ID saved
- [ ] Can see delegated subscriptions

### ✅ Customer Tenant(s)
- [ ] Sentinel instance deployed
- [ ] Test incidents created
- [ ] Lighthouse delegation deployed
- [ ] Service provider can access resources

### ✅ Lighthouse
- [ ] Delegation shows in customer tenant (`Get-AzManagedServicesAssignment`)
- [ ] Customer subscription visible in service provider tenant
- [ ] Service provider can query customer workspace

### ✅ Sync Testing
- [ ] Logic App run succeeds
- [ ] Incidents appear in main Sentinel
- [ ] Incident metadata includes source tenant info
- [ ] No duplicate incidents created

---

## Troubleshooting Multi-Tenant Setup

### Issue: Can't see delegated subscriptions

```powershell
# In service provider tenant, check:
Get-AzSubscription -IncludeMultiTenant

# Should show subscriptions from other tenants
```

**Solution:**
- Ensure Lighthouse delegation was deployed successfully in customer tenant
- Wait 5-10 minutes for propagation
- Sign out and sign back in

### Issue: "Permission denied" when querying customer workspace

**Check delegation:**
```powershell
# In customer tenant
Get-AzManagedServicesDefinition | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty Authorizations
```

**Verify roles include:**
- Microsoft Sentinel Contributor (`ab8e14d6-4a74-4a29-9ba8-549422addade`)
- Log Analytics Reader (`73c42c96-874c-492b-b04d-ab87d138a893`)

### Issue: Logic App can't authenticate

**Ensure managed identity has correct permissions:**
```powershell
# Check role assignments
Get-AzRoleAssignment -ObjectId $principalId
```

---

## Clean Up Test Environment

### Remove Lighthouse Delegation

**In customer tenant:**
```powershell
$assignment = Get-AzManagedServicesAssignment
Remove-AzManagedServicesAssignment -Id $assignment.Id
```

### Delete Resources

**Customer tenant:**
```powershell
Remove-AzResourceGroup -Name "customer-sentinel-rg" -Force
```

**Service provider tenant:**
```powershell
Remove-AzResourceGroup -Name "sentinel-sync-rg" -Force
Remove-AzResourceGroup -Name "sentinel-main-rg" -Force
```

---

## Testing Scenarios

### Scenario 1: Single Customer Test
- 1 service provider tenant
- 1 customer tenant
- Validates basic Lighthouse functionality

### Scenario 2: Multi-Customer Test
- 1 service provider tenant
- 2-3 customer tenants
- Validates concurrent sync from multiple tenants

### Scenario 3: Mixed Environment Test
- Same tenant subscriptions (no Lighthouse)
- Cross-tenant subscriptions (with Lighthouse)
- Validates both access methods work

---

## Next Steps After Successful Test

1. ✅ Document your tenant IDs and subscription mappings
2. ✅ Move configuration to Azure Key Vault
3. ✅ Set up monitoring and alerts
4. ✅ Create runbooks for onboarding new customers
5. ✅ Implement customer-specific filtering rules
6. ✅ Plan production rollout strategy

---

**Pro Tip:** Keep your test environment running for ongoing testing and development. It's much easier to troubleshoot with a working test setup!
