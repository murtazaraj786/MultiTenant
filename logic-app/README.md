# Logic App Workflow

This folder contains the standalone Logic App workflow definition files, separated from the ARM deployment template for easier editing and version control.

## Files

### `workflow.json`
The complete Logic App workflow definition including:
- **Triggers**: Recurrence trigger (default: every 5 minutes)
- **Actions**: Full incident synchronization workflow
- **Parameters**: Configurable runtime parameters

This file can be:
- Edited directly in the Azure Portal Logic App Designer
- Imported/exported for version control
- Used for testing and validation

### `connections.json`
API connection references used by the workflow:
- **azuresentinel**: Microsoft Sentinel connector (for creating/updating incidents)
- **azuremonitorlogs**: Azure Monitor Logs connector (for querying incidents)

Both connections use Managed Identity for authentication.

## Usage

### Import into Azure Portal

1. Navigate to your Logic App in Azure Portal
2. Go to **Logic App Designer**
3. Click **Code View**
4. Paste the contents of `workflow.json`
5. Save

### Export from Azure Portal

1. Open Logic App in Azure Portal
2. Go to **Logic App Designer**
3. Click **Code View**
4. Copy the workflow definition
5. Save to `workflow.json`

### Edit Locally

You can edit `workflow.json` with any JSON editor:
- Visual Studio Code (with Azure Logic Apps extension)
- Any text editor

**Tips:**
- Validate JSON syntax before deploying
- Test changes in a non-production environment first
- Keep backups before major changes

## Workflow Structure

```
workflow.json
├── parameters          # Runtime parameters ($connections, mainWorkspaceId, etc.)
├── triggers
│   └── Recurrence     # Runs every 5 minutes (configurable)
├── actions
│   ├── Initialize_ProcessedCount        # Counter variable
│   ├── Initialize_ErrorCount            # Error counter
│   ├── Get_Delegated_Tenants_Config    # Load tenant configuration
│   ├── For_Each_Delegated_Tenant       # Loop through tenants
│   │   └── Check_If_Tenant_Enabled
│   │       ├── Query_Delegated_Sentinel_Incidents  # KQL query
│   │       └── For_Each_Incident
│   │           ├── Try_Create_Or_Update_Incident
│   │           │   ├── Check_If_Incident_Exists
│   │           │   ├── Filter_Existing_Incident
│   │           │   ├── Condition_Incident_Exists
│   │           │   │   ├── Update_Existing_Incident
│   │           │   │   └── Create_New_Incident
│   │           │   └── Increment_ProcessedCount
│   │           └── Catch_Incident_Error
│   └── Log_Summary                      # Final summary
└── outputs
```

## Key Configuration Points

### Recurrence Trigger

```json
"triggers": {
  "Recurrence": {
    "recurrence": {
      "frequency": "Minute",
      "interval": 5
    }
  }
}
```

**Modify to change sync frequency:**
- Every 10 minutes: `"interval": 10`
- Every hour: `"frequency": "Hour", "interval": 1`

### KQL Query

Located in `Query_Delegated_Sentinel_Incidents` action:

```kql
SecurityIncident
| where TimeGenerated > ago(@{parameters('lookbackMinutes')}m)
| where Status in ('New', 'Active')
| project IncidentNumber, Title, Severity, Status, CreatedTime, LastModifiedTime, Owner, Description, ProviderName, AdditionalData, Labels, TenantId, _ResourceId
| order by CreatedTime desc
```

**Customize filters:**
- Add severity filter: `| where Severity in ('High', 'Medium')`
- Change status: `| where Status == 'New'`
- Add time window: `| where CreatedTime > ago(1h)`

### Incident Mapping

Located in `Create_New_Incident` and `Update_Existing_Incident` actions:

```json
"properties": {
  "title": "@{items('For_Each_Delegated_Tenant')?['tenantId']}: @{items('For_Each_Incident')?['Title']}",
  "description": "Source Tenant: @{items('For_Each_Delegated_Tenant')?['tenantId']}\nOriginal Incident Number: @{items('For_Each_Incident')?['IncidentNumber']}\n\n@{items('For_Each_Incident')?['Description']}",
  "severity": "@items('For_Each_Incident')?['Severity']",
  "status": "@items('For_Each_Incident')?['Status']"
}
```

**Customize field mappings** to change how incidents are copied.

## Deployment

### Via ARM Template

The ARM template in `deployment/arm-templates/logic-app.json` includes this workflow. When deploying via ARM, the workflow is automatically embedded.

### Manual Update

After deploying the Logic App via ARM:
1. Make changes to `workflow.json`
2. Use Azure CLI or Portal to update:

```powershell
# Using Azure CLI
az logic workflow update `
  --resource-group "sentinel-sync-rg" `
  --name "sentinel-incident-sync" `
  --definition @workflow.json
```

## Version Control

**Best Practices:**
- ✅ Commit `workflow.json` to Git after each change
- ✅ Use descriptive commit messages
- ✅ Tag releases (v1.0, v1.1, etc.)
- ✅ Export from Azure Portal regularly to capture any manual changes
- ✅ Keep development and production versions separate

## Troubleshooting

### Validate JSON

```powershell
# Test if JSON is valid
Get-Content workflow.json | ConvertFrom-Json
```

### Test Expressions

Use the **Expression Editor** in Logic App Designer to test expressions:
- `@parameters('mainWorkspaceId')`
- `@items('For_Each_Incident')?['Title']`
- `@concat(items('For_Each_Delegated_Tenant')?['tenantId'], '-', items('For_Each_Incident')?['IncidentNumber'])`

### Common Issues

**Issue**: Workflow won't save
- **Solution**: Validate JSON syntax, check for missing commas/brackets

**Issue**: Actions fail with "parameter not found"
- **Solution**: Ensure all required parameters are defined in the `parameters` section

**Issue**: Can't import into Portal
- **Solution**: Connection IDs must be updated to match your environment

## Related Documentation

- [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) - Overall architecture
- [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) - Deployment guide
- [../docs/CONFIGURATION.md](../docs/CONFIGURATION.md) - Configuration options
- [Azure Logic Apps Documentation](https://docs.microsoft.com/azure/logic-apps/)

---

**Last Updated:** November 2025
