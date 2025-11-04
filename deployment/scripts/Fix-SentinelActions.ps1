# Fix-SentinelActions.ps1
# Updates the deployed Logic App to fix Sentinel API action validation errors

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "sentinel-sync-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$LogicAppName = "sentinel-incident-sync",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "28e1e42a-4438-4c30-9a5f-7d7b488fd883"
)

Write-Host "`n=== Sentinel Logic App Action Fix Script ===" -ForegroundColor Cyan
Write-Host "This script fixes the validation errors in Sentinel incident actions`n" -ForegroundColor Yellow

# Check if Az module is available
if (-not (Get-Module -ListAvailable -Name Az.LogicApp)) {
    Write-Host "ERROR: Az.LogicApp module not found." -ForegroundColor Red
    Write-Host "Please install it with: Install-Module -Name Az -AllowClobber -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Set context
Write-Host "Setting Azure context..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop

# Get the Logic App
Write-Host "Retrieving Logic App: $LogicAppName..." -ForegroundColor Cyan
$logicApp = Get-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName -ErrorAction Stop

if (-not $logicApp) {
    Write-Host "ERROR: Logic App not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found Logic App: $($logicApp.Name)" -ForegroundColor Green

# Get the workflow definition
$definition = $logicApp.Definition

# Fix function to remove properties wrapper and add title
function Fix-SentinelAction {
    param($action)
    
    if ($action.inputs.body.properties) {
        $oldBody = $action.inputs.body.properties
        
        # Create new flat body structure
        $newBody = @{
            title = $oldBody.title
            description = $oldBody.description
            severity = $oldBody.severity
            status = $oldBody.status
        }
        
        # Remove properties wrapper
        $action.inputs.body = $newBody
        
        Write-Host "  Fixed action body structure (removed properties wrapper)" -ForegroundColor Green
        return $true
    }
    
    return $false
}

$fixed = $false

# Find and fix Create Incident actions
Write-Host "`nSearching for Sentinel incident actions..." -ForegroundColor Cyan

foreach ($actionKey in $definition.actions.Keys) {
    $action = $definition.actions[$actionKey]
    
    # Check nested actions in foreach loops and conditions
    if ($action.type -eq "Foreach" -and $action.actions) {
        foreach ($nestedKey in $action.actions.Keys) {
            $nestedAction = $action.actions[$nestedKey]
            
            if ($nestedAction.type -eq "If" -and $nestedAction.actions) {
                foreach ($conditionKey in $nestedAction.actions.Keys) {
                    $conditionAction = $nestedAction.actions[$conditionKey]
                    
                    if ($conditionAction.type -eq "ApiConnection" -and 
                        $conditionAction.inputs.host.connection.name -like "*azuresentinel*") {
                        
                        Write-Host "  Found Sentinel action: $conditionKey" -ForegroundColor Yellow
                        if (Fix-SentinelAction $conditionAction) {
                            $fixed = $true
                        }
                    }
                }
            }
            
            # Check else branch
            if ($nestedAction.type -eq "If" -and $nestedAction.else.actions) {
                foreach ($elseKey in $nestedAction.else.actions.Keys) {
                    $elseAction = $nestedAction.else.actions[$elseKey]
                    
                    if ($elseAction.type -eq "ApiConnection" -and 
                        $elseAction.inputs.host.connection.name -like "*azuresentinel*") {
                        
                        Write-Host "  Found Sentinel action: $elseKey" -ForegroundColor Yellow
                        if (Fix-SentinelAction $elseAction) {
                            $fixed = $true
                        }
                    }
                }
            }
        }
    }
}

if (-not $fixed) {
    Write-Host "`nNo actions needed fixing (they may already be correct)" -ForegroundColor Yellow
    exit 0
}

# Update the Logic App
Write-Host "`nUpdating Logic App with fixed definition..." -ForegroundColor Cyan

try {
    Set-AzLogicApp `
        -ResourceGroupName $ResourceGroupName `
        -Name $LogicAppName `
        -Definition $definition `
        -State $logicApp.State `
        -Force `
        -ErrorAction Stop
    
    Write-Host "`nSUCCESS! Logic App updated successfully." -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Go to Azure Portal -> Logic App -> Logic app designer" -ForegroundColor White
    Write-Host "2. Verify the validation errors are gone" -ForegroundColor White
    Write-Host "3. Authorize API connections (if not already done)" -ForegroundColor White
    Write-Host "4. Save and test run the Logic App" -ForegroundColor White
}
catch {
    Write-Host "`nERROR: Failed to update Logic App" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
