#!/usr/bin/env pwsh

# Quick Deploy Script for Multi-Tenant Sentinel Logic App
# This actually works and creates incidents in other tenants

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$LogicAppName = "sentinel-incident-sync"
)

Write-Host "🚀 Deploying Multi-Tenant Sentinel Logic App" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

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
Write-Host "🔨 Deploying Logic App..." -ForegroundColor Yellow

try {    
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "deploy.json" `
        -TemplateParameterFile "deploy.parameters.json" `
        -logicAppName $LogicAppName `
        -Verbose
    
    Write-Host "✅ DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    Write-Host "Logic App: $($deployment.Outputs.logicAppName.Value)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Edit deploy.parameters.json - add your target subscription details" -ForegroundColor White
Write-Host "2. Go to Azure Portal → $ResourceGroupName → $LogicAppName" -ForegroundColor White  
Write-Host "3. Go to API connections → azuresentinel → Authorize" -ForegroundColor White
Write-Host "4. Test by creating incident in source Sentinel" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Done! The Logic App will now sync incidents to target tenants." -ForegroundColor Green