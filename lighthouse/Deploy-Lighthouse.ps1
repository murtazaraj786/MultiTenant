# Azure Lighthouse Delegation Deployment Script
# Deploy this template in CUSTOMER TENANTS to delegate access to your managing tenant

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $false)]
    [string]$CustomerTenantName = "Customer Tenant"
)

# Set error handling
$ErrorActionPreference = "Stop"

Write-Host "🏗️  Azure Lighthouse Delegation Deployment" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Connect to Azure (customer tenant)
Write-Host "📋 Step 1: Connecting to Azure..." -ForegroundColor Yellow
Connect-AzAccount -SubscriptionId $SubscriptionId

# Get current context
$context = Get-AzContext
Write-Host "✅ Connected to:" -ForegroundColor Green
Write-Host "   Tenant: $($context.Tenant.Id)" -ForegroundColor White
Write-Host "   Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor White

# Deploy Lighthouse delegation
Write-Host "`n📋 Step 2: Deploying Lighthouse delegation..." -ForegroundColor Yellow

$deploymentName = "LighthouseDelegation-$(Get-Date -Format 'yyyyMMdd-HHmm')"
$templateFile = ".\lighthouse-delegation.json"

# Parameters for deployment
$parameters = @{
    managingTenantDisplayName = "Central Security Operations - $CustomerTenantName"
    offerName = "Multi-Tenant Sentinel Monitoring - $CustomerTenantName"
    offerDescription = "Automated incident synchronization and centralized security monitoring for Microsoft Sentinel workspaces in $CustomerTenantName"
}

try {
    Write-Host "🚀 Deploying template..." -ForegroundColor Yellow
    
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $Location `
        -TemplateFile $templateFile `
        -TemplateParameterObject $parameters `
        -Verbose

    Write-Host "✅ Lighthouse delegation deployed successfully!" -ForegroundColor Green
    Write-Host "`n📊 Deployment Details:" -ForegroundColor Cyan
    Write-Host "   Deployment Name: $deploymentName" -ForegroundColor White
    Write-Host "   Registration Definition ID: $($deployment.Outputs.registrationDefinitionId.Value)" -ForegroundColor White
    Write-Host "   Assignment ID: $($deployment.Outputs.assignmentId.Value)" -ForegroundColor White
    Write-Host "   Managing Tenant ID: $($deployment.Outputs.managedByTenantId.Value)" -ForegroundColor White
    
    Write-Host "`n🎯 What happens next:" -ForegroundColor Yellow
    Write-Host "   1. The Logic App can now access this customer tenant" -ForegroundColor White
    Write-Host "   2. Update your Logic App parameters to include this customer's workspaces" -ForegroundColor White
    Write-Host "   3. The managed identity has these roles:" -ForegroundColor White
    Write-Host "      • Owner (full access)" -ForegroundColor White
    Write-Host "      • Microsoft Sentinel Reader" -ForegroundColor White  
    Write-Host "      • Microsoft Sentinel Responder" -ForegroundColor White
    
    # Save delegation info to file
    $delegationInfo = @{
        DeploymentName = $deploymentName
        CustomerTenant = $context.Tenant.Id
        CustomerSubscription = $context.Subscription.Id
        CustomerSubscriptionName = $context.Subscription.Name
        RegistrationDefinitionId = $deployment.Outputs.registrationDefinitionId.Value
        AssignmentId = $deployment.Outputs.assignmentId.Value
        ManagedByTenantId = $deployment.Outputs.managedByTenantId.Value
        DeployedDate = Get-Date
        LogicAppManagedIdentity = $deployment.Outputs.logicAppManagedIdentity.Value
    }
    
    $outputFile = "lighthouse-delegation-$($context.Subscription.Id)-$(Get-Date -Format 'yyyyMMdd').json"
    $delegationInfo | ConvertTo-Json -Depth 5 | Out-File $outputFile
    Write-Host "   4. Delegation details saved to: $outputFile" -ForegroundColor White
    
}
catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Lighthouse delegation complete!" -ForegroundColor Green
Write-Host "The Logic App can now sync incidents from this customer tenant." -ForegroundColor Green