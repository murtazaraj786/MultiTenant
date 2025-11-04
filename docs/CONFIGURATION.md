# Configuration Reference

This document provides detailed configuration options for the Microsoft Sentinel Multi-Tenant Incident Synchronization solution.

## Configuration Files Overview

| File | Purpose | Location |
|------|---------|----------|
| `tenants.json` | Define delegated tenant connections | `config/tenants.json` |
| `sync-settings.json` | Control sync behavior and filters | `config/sync-settings.json` |
| `field-mappings.json` | Map incident fields between tenants | `config/field-mappings.json` |

## Tenant Configuration (`tenants.json`)

### Structure

```json
{
  "delegatedTenants": [
    {
      "tenantId": "string",
      "tenantName": "string",
      "subscriptionId": "string",
      "resourceGroup": "string",
      "workspaceName": "string",
      "workspaceId": "string",
      "enabled": boolean,
      "description": "string",
      "tags": {
        "key": "value"
      }
    }
  ],
  "mainTenant": {
    "tenantId": "string",
    "subscriptionId": "string",
    "resourceGroup": "string",
    "workspaceName": "string",
    "workspaceId": "string"
  }
}
```

### Field Descriptions

#### Delegated Tenants

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `tenantId` | string | Yes | Azure AD tenant ID of the customer | `"00000000-0000-0000-0000-000000000000"` |
| `tenantName` | string | No | Friendly name for the tenant | `"Contoso Corporation"` |
| `subscriptionId` | string | Yes | Customer's subscription ID | `"11111111-1111-1111-1111-111111111111"` |
| `resourceGroup` | string | Yes | Resource group containing Sentinel | `"sentinel-rg"` |
| `workspaceName` | string | Yes | Log Analytics workspace name | `"contoso-sentinel-workspace"` |
| `workspaceId` | string | No | Full resource ID of workspace | Auto-constructed if not provided |
| `enabled` | boolean | Yes | Whether to sync from this tenant | `true` or `false` |
| `description` | string | No | Notes about this tenant | `"Production environment"` |
| `tags` | object | No | Custom tags for categorization | `{"customer": "Contoso", "tier": "premium"}` |

#### Main Tenant

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tenantId` | string | Yes | Your service provider tenant ID |
| `subscriptionId` | string | Yes | Main subscription ID where Sentinel resides |
| `resourceGroup` | string | Yes | Resource group with main Sentinel |
| `workspaceName` | string | Yes | Main Sentinel workspace name |
| `workspaceId` | string | No | Full resource ID (auto-constructed) |

### Example Configuration

```json
{
  "delegatedTenants": [
    {
      "tenantId": "12345678-1234-1234-1234-123456789012",
      "tenantName": "Contoso Corp",
      "subscriptionId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "resourceGroup": "contoso-security-rg",
      "workspaceName": "contoso-sentinel-prod",
      "enabled": true,
      "description": "Production Sentinel instance for Contoso",
      "tags": {
        "customer": "Contoso",
        "environment": "production",
        "tier": "premium",
        "region": "eastus"
      }
    },
    {
      "tenantId": "87654321-4321-4321-4321-210987654321",
      "tenantName": "Fabrikam Inc",
      "subscriptionId": "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj",
      "resourceGroup": "fabrikam-sentinel-rg",
      "workspaceName": "fabrikam-sentinel",
      "enabled": false,
      "description": "Temporarily disabled for maintenance",
      "tags": {
        "customer": "Fabrikam",
        "environment": "production"
      }
    }
  ],
  "mainTenant": {
    "tenantId": "99999999-9999-9999-9999-999999999999",
    "subscriptionId": "kkkkkkkk-llll-mmmm-nnnn-oooooooooooo",
    "resourceGroup": "mssp-sentinel-rg",
    "workspaceName": "mssp-central-sentinel"
  }
}
```

### Best Practices

✅ **Always validate before deploying**: Use JSON validators to check syntax  
✅ **Start with `enabled: false`**: Test one tenant at a time  
✅ **Use descriptive names**: Makes troubleshooting easier  
✅ **Document with tags**: Track customers, environments, SLAs  
✅ **Store securely**: Use Azure Key Vault in production

---

## Sync Settings (`sync-settings.json`)

### Structure

```json
{
  "syncSettings": {
    "frequency": {
      "type": "string",
      "interval": number
    },
    "lookbackPeriod": {
      "minutes": number
    },
    "timeout": {
      "seconds": number
    }
  },
  "filters": {
    "severity": {
      "include": ["string"]
    },
    "status": {
      "include": ["string"],
      "exclude": ["string"]
    },
    "title": {
      "excludePatterns": ["string"]
    }
  },
  "deduplication": {
    "enabled": boolean,
    "matchFields": ["string"]
  },
  "enrichment": {
    "addSourceTenantTag": boolean,
    "prefixTitle": boolean,
    "titlePrefix": "string",
    "customLabels": ["string"]
  },
  "errorHandling": {
    "retryAttempts": number,
    "retryIntervalSeconds": number,
    "continueOnError": boolean
  },
  "performance": {
    "batchSize": number,
    "parallelTenants": number,
    "parallelIncidents": number
  }
}
```

### Sync Settings Section

#### Frequency

| Field | Type | Values | Description | Recommendation |
|-------|------|--------|-------------|----------------|
| `type` | string | `"Minute"`, `"Hour"`, `"Day"` | Trigger frequency type | `"Minute"` for near real-time |
| `interval` | number | 1-1000 | How often to run | `5` for 5-minute intervals |

**Examples:**
- Every 5 minutes: `{"type": "Minute", "interval": 5}`
- Every hour: `{"type": "Hour", "interval": 1}`
- Twice daily: `{"type": "Hour", "interval": 12}`

#### Lookback Period

| Field | Type | Description | Recommendation |
|-------|------|-------------|----------------|
| `minutes` | number | How far back to query for incidents | Set to slightly more than sync frequency (e.g., 10 for 5-min sync) |

**Considerations:**
- Too short: May miss incidents
- Too long: Processes same incidents multiple times (but deduplication handles this)
- Overlap recommended: e.g., 10-minute lookback for 5-minute sync

#### Timeout

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `seconds` | number | Maximum time for sync operation | `300` (5 minutes) |

### Filters Section

#### Severity Filter

```json
"severity": {
  "include": ["High", "Medium", "Low", "Informational"]
}
```

**Options:**
- `"High"`: Critical security incidents
- `"Medium"`: Important security incidents
- `"Low"`: Minor security incidents
- `"Informational"`: Informational alerts

**Common Configurations:**

*Critical Only:*
```json
"severity": {
  "include": ["High"]
}
```

*High & Medium:*
```json
"severity": {
  "include": ["High", "Medium"]
}
```

*All Severities:*
```json
"severity": {
  "include": ["High", "Medium", "Low", "Informational"]
}
```

#### Status Filter

```json
"status": {
  "include": ["New", "Active"],
  "exclude": ["Closed"]
}
```

**Options:**
- `"New"`: Newly created incidents
- `"Active"`: Under investigation
- `"Closed"`: Resolved incidents

**Common Configurations:**

*Active Incidents Only:*
```json
"status": {
  "include": ["New", "Active"],
  "exclude": ["Closed"]
}
```

*All Statuses:*
```json
"status": {
  "include": ["New", "Active", "Closed"],
  "exclude": []
}
```

#### Title Filter

```json
"title": {
  "excludePatterns": ["Test", "Demo", "Sandbox"]
}
```

Excludes incidents with titles containing these patterns (case-insensitive).

### Deduplication Section

```json
"deduplication": {
  "enabled": true,
  "matchFields": ["sourceIncidentId", "sourceTenantId"]
}
```

| Field | Type | Description | Recommendation |
|-------|------|-------------|----------------|
| `enabled` | boolean | Enable deduplication | Always `true` |
| `matchFields` | array | Fields to match for duplicates | `["sourceIncidentId", "sourceTenantId"]` |

**How It Works:**
1. Logic App constructs unique ID: `{tenantId}-{incidentNumber}`
2. Queries main Sentinel for incidents with matching `sourceIncidentId`
3. If found: Updates existing incident
4. If not found: Creates new incident

### Enrichment Section

```json
"enrichment": {
  "addSourceTenantTag": true,
  "addSourceWorkspaceTag": true,
  "prefixTitle": true,
  "titlePrefix": "{tenantId}: ",
  "customLabels": ["Multi-Tenant", "Lighthouse-Synced"]
}
```

| Field | Type | Description | Example Result |
|-------|------|-------------|----------------|
| `addSourceTenantTag` | boolean | Add tenant ID to incident metadata | ✅ Recommended |
| `addSourceWorkspaceTag` | boolean | Add workspace name to metadata | ✅ Recommended |
| `prefixTitle` | boolean | Add prefix to incident title | ✅ Recommended for clarity |
| `titlePrefix` | string | Text to prefix (supports variables) | `"Contoso: "` or `"{tenantId}: "` |
| `customLabels` | array | Add custom labels to incidents | For filtering/grouping |

**Variables Available:**
- `{tenantId}`: Customer tenant ID
- `{tenantName}`: Friendly tenant name
- `{workspaceName}`: Source workspace name

### Error Handling Section

```json
"errorHandling": {
  "retryAttempts": 3,
  "retryIntervalSeconds": 30,
  "continueOnError": true,
  "logErrors": true
}
```

| Field | Type | Description | Recommendation |
|-------|------|-------------|----------------|
| `retryAttempts` | number | How many times to retry failed operations | `3` |
| `retryIntervalSeconds` | number | Wait time between retries | `30` (with exponential backoff) |
| `continueOnError` | boolean | Continue to next tenant/incident on error | `true` for resilience |
| `logErrors` | boolean | Log errors for troubleshooting | `true` |

### Performance Section

```json
"performance": {
  "batchSize": 50,
  "parallelTenants": 1,
  "parallelIncidents": 1
}
```

| Field | Type | Description | Recommendation |
|-------|------|-------------|----------------|
| `batchSize` | number | Max incidents to process per tenant | `50` (adjust based on volume) |
| `parallelTenants` | number | How many tenants to process simultaneously | `1` to avoid throttling |
| `parallelIncidents` | number | How many incidents to process simultaneously | `1` to avoid throttling |

**Concurrency Considerations:**

*Conservative (Recommended):*
```json
"performance": {
  "batchSize": 25,
  "parallelTenants": 1,
  "parallelIncidents": 1
}
```

*Aggressive (Higher Risk of Throttling):*
```json
"performance": {
  "batchSize": 100,
  "parallelTenants": 3,
  "parallelIncidents": 5
}
```

---

## Field Mappings (`field-mappings.json`)

### Structure

```json
{
  "fieldMappings": {
    "mappings": [
      {
        "sourceField": "string",
        "destinationField": "string",
        "transform": "string",
        "transformValue": "varies",
        "required": boolean,
        "description": "string"
      }
    ],
    "customFields": [
      {
        "field": "string",
        "value": "string",
        "description": "string"
      }
    ]
  }
}
```

### Mapping Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `sourceField` | string | Field name in source incident | `"IncidentNumber"` |
| `destinationField` | string | Field name in destination incident | `"additionalData.sourceIncidentNumber"` |
| `transform` | string | Transformation to apply | `"prefix"`, `"none"`, `"mapping"` |
| `transformValue` | varies | Value for transformation | Depends on transform type |
| `required` | boolean | Is this field required? | `true` or `false` |
| `description` | string | Documentation for this mapping | `"Original incident ID"` |

### Transform Types

#### 1. None (Pass-Through)

```json
{
  "sourceField": "Severity",
  "destinationField": "severity",
  "transform": "none",
  "required": true
}
```

Value copied as-is with no modification.

#### 2. Prefix

```json
{
  "sourceField": "Title",
  "destinationField": "title",
  "transform": "prefix",
  "transformValue": "Customer-A: ",
  "required": true
}
```

Adds text before the value.  
Example: `"Malware Detected"` → `"Customer-A: Malware Detected"`

#### 3. Prepend (with newline)

```json
{
  "sourceField": "Description",
  "destinationField": "description",
  "transform": "prepend",
  "transformValue": "Source: {tenantId}\n\n",
  "required": false
}
```

Adds text with newlines before value.  
Example:
```
"Suspicious activity detected"
→
"Source: 12345678-1234-1234-1234-123456789012

Suspicious activity detected"
```

#### 4. Append (for arrays)

```json
{
  "sourceField": "Labels",
  "destinationField": "labels",
  "transform": "append",
  "transformValue": ["Multi-Tenant", "Synced"],
  "required": false
}
```

Adds values to an array.  
Example: `["Alert", "Malware"]` → `["Alert", "Malware", "Multi-Tenant", "Synced"]`

#### 5. Mapping (value translation)

```json
{
  "sourceField": "Severity",
  "destinationField": "severity",
  "transform": "mapping",
  "mapping": {
    "High": "Critical",
    "Medium": "Warning",
    "Low": "Info"
  },
  "required": true
}
```

Translates values using a dictionary.  
Example: `"High"` → `"Critical"`

### Standard Field Mappings

#### Core Incident Fields

| Source Field | Destination Field | Description |
|--------------|-------------------|-------------|
| `IncidentNumber` | `additionalData.sourceIncidentNumber` | Original incident ID |
| `Title` | `title` | Incident title (usually with prefix) |
| `Description` | `description` | Full description |
| `Severity` | `severity` | `High`, `Medium`, `Low`, `Informational` |
| `Status` | `status` | `New`, `Active`, `Closed` |
| `CreatedTime` | `additionalData.sourceCreatedTime` | Original creation timestamp |
| `LastModifiedTime` | `additionalData.sourceLastModifiedTime` | Last update timestamp |
| `Owner` | `owner` | Assigned user |
| `Labels` | `labels` | Tags/labels |

#### Metadata Fields

| Source Field | Destination Field | Description |
|--------------|-------------------|-------------|
| `TenantId` | `additionalData.sourceTenantId` | Customer tenant ID |
| `_ResourceId` | `additionalData.sourceResourceId` | Full resource path |
| `ProviderName` | `additionalData.sourceProvider` | Alert provider |

### Custom Fields

Add metadata that doesn't come from source incident:

```json
"customFields": [
  {
    "field": "additionalData.syncedBy",
    "value": "LogicApp-Multi-Tenant-Sync",
    "description": "Identifies synced incidents"
  },
  {
    "field": "additionalData.syncTime",
    "value": "{utcNow}",
    "description": "When incident was synced"
  }
]
```

**Variables:**
- `{utcNow}`: Current UTC timestamp
- `{tenantId}`: Source tenant ID
- `{tenantName}`: Source tenant name
- `{workspaceName}`: Source workspace name

### Complete Example

```json
{
  "fieldMappings": {
    "mappings": [
      {
        "sourceField": "IncidentNumber",
        "destinationField": "additionalData.sourceIncidentNumber",
        "transform": "none",
        "required": true,
        "description": "Preserve original incident number"
      },
      {
        "sourceField": "Title",
        "destinationField": "title",
        "transform": "prefix",
        "transformValue": "[{tenantName}] ",
        "required": true,
        "description": "Add tenant name to title"
      },
      {
        "sourceField": "Description",
        "destinationField": "description",
        "transform": "prepend",
        "transformValue": "**Source Tenant:** {tenantName} ({tenantId})\n**Original Incident:** #{IncidentNumber}\n**Workspace:** {workspaceName}\n\n---\n\n",
        "required": false,
        "description": "Add context to description"
      },
      {
        "sourceField": "Severity",
        "destinationField": "severity",
        "transform": "none",
        "required": true,
        "description": "Keep severity as-is"
      }
    ],
    "customFields": [
      {
        "field": "additionalData.syncSource",
        "value": "Azure-Lighthouse-Multi-Tenant-Sync",
        "description": "Tag for synced incidents"
      },
      {
        "field": "additionalData.syncTimestamp",
        "value": "{utcNow}",
        "description": "Sync timestamp"
      }
    ]
  }
}
```

---

## Configuration Best Practices

### Security

✅ **Never commit sensitive data**: Don't put credentials in config files  
✅ **Use Key Vault**: Store configs in Azure Key Vault for production  
✅ **Restrict access**: Use RBAC to control who can modify configs  
✅ **Audit changes**: Track all configuration changes

### Maintenance

✅ **Version control**: Keep configs in Git  
✅ **Environment separation**: Different configs for dev/test/prod  
✅ **Document changes**: Use comments or change logs  
✅ **Test before deploy**: Validate JSON syntax and test with one tenant

### Performance

✅ **Start conservative**: Low frequency, narrow filters  
✅ **Monitor and adjust**: Use metrics to optimize  
✅ **Filter at source**: Use KQL to reduce data transfer  
✅ **Batch appropriately**: Balance throughput vs. throttling

---

**Last Updated:** November 2025  
**Version:** 1.0.0
