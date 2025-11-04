# Architecture Overview

## Solution Architecture

The Microsoft Sentinel Multi-Tenant Incident Synchronization solution uses Azure Lighthouse to enable cross-tenant security operations. This architecture allows a central Security Operations Center (SOC) to monitor and manage security incidents across multiple customer tenants from a single pane of glass.

## High-Level Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Service Provider Tenant                         │
│                          (Main/Central SOC)                           │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                  Microsoft Sentinel (Main)                       │ │
│  │                                                                  │ │
│  │  • Aggregated Incidents from All Tenants                       │ │
│  │  • Unified Dashboard & Analytics                               │ │
│  │  • Central Incident Response & Management                      │ │
│  │  • Cross-Tenant Correlation                                    │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               ▲                                       │
│                               │                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                 Azure Logic App (Orchestrator)                   │ │
│  │                                                                  │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │ │
│  │  │  Recurrence  │→ │  Query All   │→ │  Transform   │        │ │
│  │  │   Trigger    │  │   Tenants    │  │   & Create   │        │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘        │ │
│  │                                                                  │ │
│  │  Components:                                                     │ │
│  │  • Scheduled Trigger (5 min interval)                          │ │
│  │  • Tenant Configuration Loader                                  │ │
│  │  • KQL Query Engine                                            │ │
│  │  • Field Mapping & Transformation                              │ │
│  │  • Deduplication Logic                                         │ │
│  │  • Error Handling & Retry                                      │ │
│  │                                                                  │ │
│  │  Identity: System-Assigned Managed Identity                     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                               │                                       │
│                      Azure Lighthouse                                 │
│                      (Cross-Tenant Access)                            │
└───────────────────────────────┼───────────────────────────────────────┘
                                │
                                │ Delegated Access with RBAC
                                │
                ┌───────────────┴───────────────┐
                │                               │
┌───────────────▼─────────────┐    ┌───────────▼──────────────┐
│    Customer Tenant 1        │    │    Customer Tenant N     │
│                             │    │                          │
│  ┌───────────────────────┐  │    │  ┌────────────────────┐  │
│  │  Microsoft Sentinel   │  │    │  │ Microsoft Sentinel │  │
│  │                       │  │    │  │                    │  │
│  │  • Local Incidents    │  │... │  │ • Local Incidents  │  │
│  │  • Security Alerts    │  │    │  │ • Security Alerts  │  │
│  │  • Analytics Rules    │  │    │  │ • Analytics Rules  │  │
│  └───────────────────────┘  │    │  └────────────────────┘  │
│             ▲                │    │           ▲              │
│             │                │    │           │              │
│  ┌──────────┴─────────────┐  │    │  ┌────────┴───────────┐  │
│  │ Log Analytics Workspace │  │    │  │ Log Analytics WS   │  │
│  └─────────────────────────┘  │    │  └────────────────────┘  │
│                             │    │                          │
│  Delegated Permissions:      │    │  Delegated Permissions: │
│  • Sentinel Contributor      │    │  • Sentinel Contributor │
│  • Log Analytics Reader      │    │  • Log Analytics Reader │
└─────────────────────────────┘    └─────────────────────────┘
```

## Component Details

### 1. Azure Logic App (Orchestrator)

The Logic App is the heart of the synchronization engine:

**Workflow Steps:**
1. **Trigger**: Recurrence trigger fires every 5 minutes (configurable)
2. **Initialize Variables**: Set up counters for processed incidents and errors
3. **Load Configuration**: Retrieve delegated tenant configuration
4. **For Each Tenant Loop**:
   - Check if tenant is enabled
   - Execute KQL query against delegated Sentinel workspace
   - Retrieve incidents from last sync window
   - Apply filters (severity, status)
5. **For Each Incident Loop**:
   - Check for existing incident (deduplication)
   - Transform field data according to mappings
   - Create new incident or update existing
   - Handle errors with retry logic
6. **Logging**: Record sync summary and metrics

**Key Features:**
- **Managed Identity**: Uses system-assigned managed identity for authentication
- **Parallel Processing**: Configurable concurrency control
- **Error Handling**: Try-Catch blocks with retry logic
- **Idempotent**: Safe to run multiple times without creating duplicates

### 2. Azure Lighthouse

Azure Lighthouse provides the cross-tenant access mechanism:

**Setup Requirements:**
- Customer tenants must delegate subscriptions to service provider tenant
- Delegation grants specific RBAC roles without credentials
- Service provider accesses resources as if they were in their own tenant

**Required Permissions:**
- `Microsoft Sentinel Contributor`: Create/update incidents
- `Log Analytics Reader`: Query workspace data

**Benefits:**
- No credentials to manage
- Customer maintains full control
- Audit trail of all actions
- Can revoke access anytime

### 3. Microsoft Sentinel Instances

**Main Tenant Sentinel:**
- Central repository for all incidents
- Unified dashboard and analytics
- Correlation across tenants
- SOC team works from single interface

**Delegated Tenant Sentinels:**
- Each customer has their own Sentinel instance
- Incidents generated from their security data
- Remains fully functional independently
- Original incidents are never modified

### 4. Data Flow

```
Step 1: Trigger
  Logic App scheduled trigger fires
  
Step 2: Query
  For each enabled delegated tenant:
    → Authenticate using Managed Identity
    → Execute KQL query via Azure Monitor Logs API
    → Query: SecurityIncident table
    → Filters: TimeGenerated, Status, Severity
    
Step 3: Transform
  For each incident returned:
    → Extract source metadata
    → Apply field mappings
    → Add tenant identification tags
    → Prepare incident creation payload
    
Step 4: Deduplication
  → Calculate unique identifier (tenantId-incidentNumber)
  → Query main Sentinel for existing incident
  → Determine if create or update operation
  
Step 5: Sync
  → Call Sentinel API to create/update incident
  → Preserve source tenant metadata
  → Add custom labels and tags
  
Step 6: Log
  → Increment counters
  → Log any errors
  → Output summary statistics
```

## Security Architecture

### Authentication & Authorization

```
Logic App Managed Identity
        │
        ├─→ Main Tenant
        │   └─→ Microsoft Sentinel Contributor (create incidents)
        │
        └─→ Delegated Tenants (via Lighthouse)
            └─→ Microsoft Sentinel Contributor (read incidents)
            └─→ Log Analytics Reader (query workspace)
```

### Data Security

- **In-Transit**: All API calls use HTTPS/TLS 1.2+
- **At-Rest**: Sentinel data encrypted with Microsoft-managed keys
- **Authentication**: Azure AD with Managed Identity (no credentials stored)
- **Authorization**: RBAC with least-privilege access
- **Audit**: All actions logged in Azure Activity Log

### Compliance Considerations

- **Data Residency**: Incidents copied across tenant boundaries
- **Data Retention**: Follows Sentinel workspace retention policies
- **Privacy**: Review for PII/sensitive data in incident descriptions
- **Compliance**: Ensure cross-border data transfer compliance (GDPR, etc.)

## Scalability & Performance

### Limits & Throttling

| Component | Limit | Mitigation |
|-----------|-------|------------|
| Logic App Actions | 50,000/month (Consumption) | Use Standard plan for higher limits |
| Sentinel API | 100 requests/min | Implement concurrency control |
| KQL Query | 64 MB result size | Use pagination, filter at source |
| Lighthouse Delegations | No hard limit | Manage in batches |

### Performance Optimization

1. **Reduce Query Scope**:
   - Use short lookback periods (5-10 minutes)
   - Filter by severity/status in KQL
   - Project only needed columns

2. **Concurrency Control**:
   - Process tenants sequentially to avoid throttling
   - Use parallel processing for independent operations
   - Implement exponential backoff

3. **Deduplication**:
   - Use additionalData for tracking source IDs
   - Query main Sentinel efficiently
   - Cache results within run

### Scalability Patterns

**Current Design**: Sequential processing of tenants
- **Pros**: Simple, avoids throttling
- **Cons**: Scales linearly with tenant count
- **Good For**: Up to 50 tenants

**Future Enhancement**: Parallel tenant processing
- **Implementation**: Fan-out pattern with nested Logic Apps
- **Pros**: Scales horizontally
- **Cons**: More complex error handling
- **Good For**: 50+ tenants

## Monitoring & Observability

### Key Metrics

1. **Logic App Metrics**:
   - Run success/failure rate
   - Run duration
   - Action execution count
   - Billable action executions

2. **Sync Metrics**:
   - Incidents processed per run
   - Error count per run
   - Incidents created vs. updated
   - Sync latency (incident creation to sync)

3. **Health Metrics**:
   - Consecutive failures
   - API throttling events
   - Permission errors

### Logging Strategy

```
Azure Monitor / Log Analytics
  │
  ├─→ Logic App Run History
  │   • Input/output for each action
  │   • Error messages and stack traces
  │   • Execution timeline
  │
  ├─→ Sentinel Activity Logs
  │   • Incident creation/updates
  │   • API calls made by managed identity
  │
  └─→ Custom Logging (Future)
      • Sync summary per run
      • Tenant-specific metrics
      • Deduplication statistics
```

### Alerting

Recommended alerts:
- Logic App consecutive failures (3+)
- No incidents synced in 24 hours (if unusual)
- High error rate (>10%)
- Permission denied errors
- API throttling events

## Disaster Recovery

### Backup Strategy

- **Logic App Definition**: Stored in ARM templates (IaC)
- **Configuration**: Stored in source control
- **State**: Stateless design, no backup needed

### Recovery Procedures

1. **Logic App Failure**: Redeploy from ARM template
2. **Permission Loss**: Re-run Grant-Permissions.ps1
3. **Tenant Delegation Revoked**: Contact customer to restore
4. **Missed Sync Window**: Increase lookback period temporarily

### High Availability

- **Logic App**: Built-in Azure SLA (99.9%)
- **Sentinel API**: Built-in Azure SLA (99.9%)
- **Multi-Region**: Deploy additional Logic Apps in other regions (active-passive)

## Cost Estimation

### Monthly Cost Breakdown (Estimated)

**Logic App (Consumption Plan)**:
- Trigger executions: ~8,640/month (every 5 min)
- Actions per run: ~50 (varies by tenant count)
- Total actions: ~432,000/month
- Cost: ~$160/month

**API Calls**:
- Sentinel API: Included with Sentinel license
- Azure Monitor Logs API: Included with workspace

**Storage**:
- Incident data: Follows Sentinel pricing
- No additional storage for Logic App

**Total Estimated Cost**: ~$160/month
*Note: Costs vary based on tenant count, incident volume, and sync frequency*

### Cost Optimization

- Reduce sync frequency if real-time not required
- Filter incidents at source to reduce processing
- Use Logic App Standard plan for predictable billing at scale

## Future Enhancements

### Potential Improvements

1. **Bidirectional Sync**: Update source incidents based on main tenant changes
2. **Real-Time Sync**: Event-driven triggers instead of polling
3. **Advanced Correlation**: ML-based incident correlation across tenants
4. **Custom Enrichment**: Add threat intelligence, asset data
5. **Automated Response**: Trigger playbooks on synced incidents
6. **Multi-Region**: Deploy in multiple Azure regions for resilience
7. **Secure Configuration**: Store tenant config in Azure Key Vault
8. **Advanced Analytics**: Power BI dashboards for sync metrics

### Integration Opportunities

- **ServiceNow**: Create tickets for synced incidents
- **Teams/Slack**: Notifications for high-severity incidents
- **Azure Automation**: Automated remediation playbooks
- **Power Automate**: Approval workflows for incident actions

## Best Practices

### Design Principles

✅ **Idempotency**: Safe to run multiple times
✅ **Loose Coupling**: Tenants can be added/removed easily
✅ **Error Isolation**: One tenant failure doesn't affect others
✅ **Auditability**: All actions are logged
✅ **Security First**: Least-privilege access, managed identity

### Operational Best Practices

✅ Test with one tenant before scaling
✅ Monitor run history regularly
✅ Set up alerts for failures
✅ Document all Lighthouse delegations
✅ Review permissions quarterly
✅ Keep ARM templates in source control
✅ Use separate environments (dev/prod)

## Conclusion

This architecture provides a robust, secure, and scalable solution for multi-tenant Sentinel incident management. By leveraging Azure Lighthouse and Logic Apps, it enables efficient cross-tenant security operations while maintaining security boundaries and customer control.
