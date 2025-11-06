#!/usr/bin/env pwsh

# Deploy Central Incident Collector
# Deploy this ONCE in your central tenant to pull incidents from ALL remote tenants

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$LogicAppName = "central-sentinel-sync",
    
    [Parameter(Mandatory=$false)]
    [int]$PollingIntervalMinutes = 5
)

Write-Host "🏢 Deploying Central Sentinel Sync Logic App" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "This Logic App will pull incidents FROM remote tenants TO this central tenant" -ForegroundColor Cyan

# Check if logged in
$context = Get-AzContext
if (-not $context) {
    Write-Host "❌ Please login first: Connect-AzAccount" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Logged in as: $($context.Account.Id)" -ForegroundColor Green

# Check resource group
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "❌ Resource group '$ResourceGroupName' not found" -ForegroundColor Red
    $create = Read-Host "Create it? (y/n)"
    if ($create -eq 'y') {
        New-AzResourceGroup -Name $ResourceGroupName -Location "East US"
        Write-Host "✅ Created resource group" -ForegroundColor Green
    } else {
        exit 1
    }
}

# Deploy
Write-Host "🔨 Deploying Central Collector Logic App..." -ForegroundColor Yellow

try {    
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "central-sentinel-sync.json" `
        -TemplateParameterFile "central-sentinel-sync.parameters.json" `
        -logicAppName $LogicAppName `
        -pollingIntervalMinutes $PollingIntervalMinutes `
        -Verbose
    
    Write-Host "✅ DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    Write-Host "Logic App: $($deployment.Outputs.logicAppName.Value)" -ForegroundColor White
    Write-Host "Polling Interval: $($deployment.Outputs.pollingInterval.Value)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. 📝 Edit central-collector.parameters.json with your remote Sentinel details:" -ForegroundColor White
Write-Host "   - Add all remote subscription IDs, resource groups, and workspace names" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 🔐 Authorize API Connection:" -ForegroundColor White
Write-Host "   - Go to Azure Portal → $ResourceGroupName → $LogicAppName" -ForegroundColor Gray
Write-Host "   - Go to API connections → azuresentinel → Authorize" -ForegroundColor Gray
Write-Host "   - Sign in with account that has READ access to ALL remote Sentinel workspaces" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 🛡️ Configure Permissions:" -ForegroundColor White
Write-Host "   - Grant the Logic App's managed identity 'Microsoft Sentinel Reader' on all remote workspaces" -ForegroundColor Gray
Write-Host "   - Use Azure Lighthouse for cross-tenant access (recommended)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 🚀 Redeploy with Updated Parameters:" -ForegroundColor White
Write-Host "   .\deploy-central.ps1 -ResourceGroupName '$ResourceGroupName'" -ForegroundColor Gray
Write-Host ""
Write-Host "5. ✅ Test:" -ForegroundColor White
Write-Host "   - Create incident in any remote Sentinel workspace" -ForegroundColor Gray
Write-Host "   - Wait up to $PollingIntervalMinutes minutes" -ForegroundColor Gray
Write-Host "   - Check this central Sentinel for imported incident" -ForegroundColor Gray
Write-Host ""
Write-Host "🎯 ADVANTAGES of Central Deployment:" -ForegroundColor Green
Write-Host "✅ Single Logic App to manage (not one per remote tenant)" -ForegroundColor White
Write-Host "✅ Centralized configuration and monitoring" -ForegroundColor White
Write-Host "✅ Easy to add/remove remote tenants" -ForegroundColor White
Write-Host "✅ Polling-based (reliable, no webhook dependencies)" -ForegroundColor White
Write-Host ""
Write-Host "⚡ Change polling frequency anytime with -PollingIntervalMinutes parameter" -ForegroundColor Yellow