# Enhanced Workflow - Entities & Source Links

## 🚀 What's New in This Version

This enhanced workflow adds **entity extraction** and **source incident links** to your incident sync!

### New Features

#### 1. ✅ **Entity Extraction**
Automatically extracts and categorizes entities from each incident:
- 👤 **Accounts** (users, service accounts)
- 💻 **Hosts** (devices, computers, servers)
- 🌐 **IP Addresses** (internal & external)
- 📁 **Files** (malware, executables, suspicious files)
- 🔗 **URLs** (malicious links, C2 domains)
- 📝 **Processes** (running executables)
- And more...

#### 2. ✅ **Source Incident Link**
Direct link back to the original incident in the Azure Portal:
- Click to open source incident
- Works for both Azure Portal and Defender XDR incidents
- No manual searching needed!

#### 3. ✅ **Enhanced Metadata**
- MITRE ATT&CK tactics
- Alert count and product names
- Timeline information (first/last activity)
- Provider information (Sentinel vs XDR)

---

## 📊 New Workflow Structure

### Enhanced Actions Flow

```
For each remote workspace:
  ├─ Get incidents (existing)
  ├─ Parse incidents (existing)
  └─ For each incident:
      ├─ 🆕 Get incident entities (NEW!)
      ├─ 🆕 Parse entities response (NEW!)
      ├─ 🆕 Build entity summary (NEW!)
      ├─ 🆕 Get top 10 entities (NEW!)
      └─ Create incident with enriched description
```

### API Calls Per Incident
- **Before**: 2 calls (GET incident + PUT incident)
- **Now**: 3 calls (GET incident + GET entities + PUT incident)
- **Overhead**: +1 call = 50% increase but HUGE value!

---

## 📝 Enhanced Description Format

The synced incidents now include a beautifully formatted description:

```markdown
# 🔗 Source Information
Source Workspace: AutoLAW
Original Incident #: 1234
Original Incident ID: abc-123-def
Source Portal Link: https://portal.azure.com/#asset/...
Provider: Azure Sentinel

# 📊 Incident Timeline
Created: 2024-11-06T10:30:00Z
First Activity: 2024-11-06T10:00:00Z
Last Activity: 2024-11-06T12:30:00Z

# 👥 Entities (15 total)
Accounts: 3 | Hosts: 2 | IPs: 5
Files: 2 | URLs: 2 | Processes: 1

## Top Entities (First 10):
- **Account**: john.doe@company.com
- **Account**: admin@company.com
- **Host**: DESKTOP-ABC123
- **Host**: SERVER-001
- **Ip**: 192.168.1.100
- **Ip**: 10.0.0.5
- **Ip**: 203.0.113.50 (external)
- **File**: malware.exe
- **Url**: http://malicious-domain.com
- **Process**: powershell.exe

# 🎯 MITRE ATT&CK Tactics
InitialAccess, Execution, Persistence, PrivilegeEscalation

# 🚨 Alert Details
Alert Count: 5
Alert Products: Microsoft Defender for Endpoint, Azure Sentinel

---

# 📝 Original Description
[Original incident description here]
```

---

## 🔧 Deployment

### Option 1: Deploy New Enhanced Workflow

1. **Create new Logic App** (or update existing)
2. **Copy/paste** `workflow-ENHANCED-ENTITIES.json` into code view
3. **Save** - parameters are already configured
4. **Assign RBAC** (same as before - no additional permissions needed!)
5. **Run** and enjoy the enhanced data!

### Option 2: Side-by-Side Comparison

Run both workflows:
- **Basic**: `workflow-CODE-VIEW.json` (lightweight, 2 API calls)
- **Enhanced**: `workflow-ENHANCED-ENTITIES.json` (feature-rich, 3 API calls)

Compare the synced incidents to see the difference!

---

## 📋 What Gets Extracted

### Entity Types Captured

| Entity Type | Example | Description |
|-------------|---------|-------------|
| **Account** | `john.doe@company.com` | User accounts, service principals |
| **Host** | `DESKTOP-ABC123` | Computers, servers, devices |
| **Ip** | `192.168.1.100` | Internal and external IP addresses |
| **File** | `malware.exe (SHA256: abc...)` | Files with hashes, paths |
| **Url** | `http://malicious-site.com` | URLs, domains |
| **Process** | `powershell.exe -enc ...` | Running processes, command lines |
| **MailMessage** | `phishing@evil.com` | Email addresses, subjects |
| **CloudResource** | `/subscriptions/.../vm001` | Azure resources |
| **Registry** | `HKLM\Software\...` | Registry keys |
| **FileHash** | `SHA256: abc123...` | File hashes |

### Entity Summary Counts

The workflow automatically counts entities by type:
```json
{
  "accounts": 3,
  "hosts": 2,
  "ips": 5,
  "files": 2,
  "urls": 2,
  "processes": 1,
  "totalEntities": 15
}
```

---

## 🎯 Use Cases

### Why This Matters

#### 1. **Immediate Context**
SOC analysts see WHO and WHAT was involved without clicking through

#### 2. **Cross-Tenant Correlation**
Quickly identify if the same user/IP appears in incidents across workspaces

#### 3. **Threat Hunting**
Search for specific IPs, users, or files across all synced incidents

#### 4. **Rapid Response**
Know which systems/users to investigate immediately

#### 5. **One-Click Source Access**
Click the source link to view full investigation in original workspace

---

## 🔍 Example Queries

### Find All Incidents Involving a Specific User

```kusto
SecurityIncident
| where Title startswith "[SYNCED]"
| where Description contains "john.doe@company.com"
| project TimeGenerated, Title, Severity, Description
```

### Find Incidents with Specific IP Address

```kusto
SecurityIncident
| where Title startswith "[SYNCED]"
| where Description contains "192.168.1.100"
| project TimeGenerated, Title, SourceWorkspace=tostring(parse_json(Description).SourceWorkspace)
```

### Count Entities by Type Across All Synced Incidents

```kusto
SecurityIncident
| where Title startswith "[SYNCED]"
| extend EntitiesSection = extract(@"# 👥 Entities \((\d+) total\)", 1, Description)
| extend Accounts = toint(extract(@"Accounts: (\d+)", 1, Description))
| extend Hosts = toint(extract(@"Hosts: (\d+)", 1, Description))
| extend IPs = toint(extract(@"IPs: (\d+)", 1, Description))
| summarize 
    TotalIncidents=count(),
    TotalAccounts=sum(Accounts),
    TotalHosts=sum(Hosts),
    TotalIPs=sum(IPs)
```

---

## ⚡ Performance Impact

### Current Workflow (Basic)
- **API Calls per incident**: 2
- **API Calls per run** (2 workspaces, 10 incidents each): ~40
- **Runtime**: ~10-15 seconds

### Enhanced Workflow
- **API Calls per incident**: 3 (+1 for entities)
- **API Calls per run**: ~60 (+50%)
- **Runtime**: ~15-20 seconds (+5 seconds)
- **Value increase**: 🚀🚀🚀🚀🚀 MASSIVE!

### Still Well Within Limits
- Azure Management API: 12,000 reads/hour
- Your usage: 60 calls per 5 min = 720 calls/hour
- **Headroom**: 94% capacity remaining ✅

---

## 🔐 Security & Permissions

### Same RBAC Requirements
No additional permissions needed! Uses same roles:

**Remote workspaces**:
- `Microsoft Sentinel Reader` (8d289c81-5878-46d4-8554-54e1e3d8b5cb)

**Central workspace**:
- `Microsoft Sentinel Contributor` (ab8e14d6-4a74-4a29-9ba8-549422addade)

The `/entities` endpoint is included in Sentinel Reader permissions.

---

## 🆚 Comparison

### Basic vs Enhanced

| Feature | Basic Workflow | Enhanced Workflow |
|---------|----------------|-------------------|
| Incident Title | ✅ | ✅ |
| Incident Description | ✅ | ✅ Enhanced |
| Severity | ✅ | ✅ |
| Status | ✅ | ✅ |
| Source Workspace | ✅ | ✅ |
| Incident Number | ✅ | ✅ |
| Creation Time | ✅ | ✅ |
| **Source Portal Link** | ❌ | ✅ **NEW!** |
| **Entity Extraction** | ❌ | ✅ **NEW!** |
| **Entity Counts** | ❌ | ✅ **NEW!** |
| **Top 10 Entities** | ❌ | ✅ **NEW!** |
| **MITRE Tactics** | ❌ | ✅ **NEW!** |
| **Alert Count** | ❌ | ✅ **NEW!** |
| **Timeline** | ❌ | ✅ **NEW!** |
| **Provider Info** | ❌ | ✅ **NEW!** |
| API Calls/Incident | 2 | 3 |
| Description Format | Plain text | Markdown |

---

## 🐛 Troubleshooting

### Entities Not Showing Up

**Problem**: Entity section shows "0 total" or "No entities found"

**Causes**:
1. **Manually created incidents** don't have entities until alerts are added
2. **Very new incidents** might not have entities extracted yet
3. **Analytics rule** didn't map entities

**Solutions**:
- Check source incident has entities in Azure Portal
- Wait a few minutes and re-sync
- Verify analytics rules have entity mapping configured

### Source Link Not Working

**Problem**: Source Portal Link shows as "undefined" or broken

**Cause**: `incidentUrl` property not in API response (rare)

**Solution**: 
- This is normal for very old incidents
- Link will work for all new incidents (created after 2021)
- You can still use Incident ID to search in source workspace

### Description Too Long

**Problem**: Incident description truncated

**Cause**: Sentinel has 5,000 character limit for description

**Solution**: Already handled! Workflow uses `coalesce()` and safe string operations

---

## 📚 Additional Resources

### API Documentation
- [Sentinel Incidents API](https://learn.microsoft.com/rest/api/securityinsights/incidents)
- [Incident Entities API](https://learn.microsoft.com/rest/api/securityinsights/incident-entities)
- [Entity Types Reference](https://learn.microsoft.com/azure/sentinel/entities-reference)

### Related Docs
- `SYNC-OPTIMIZATION-GUIDE.md` - Full optimization strategies
- `XDR-INTEGRATION-IMPACT.md` - XDR compatibility
- `README.md` - Main documentation

---

## ✅ Checklist

Before deploying enhanced workflow:

- [ ] Backup current workflow (export JSON)
- [ ] Test in dev/test Logic App first
- [ ] Verify RBAC permissions are assigned
- [ ] Run manually and check outputs
- [ ] Compare synced incident with source
- [ ] Verify entity counts are accurate
- [ ] Test source portal link works
- [ ] Monitor for 24 hours
- [ ] Compare API call metrics
- [ ] Deploy to production

---

## 🎉 What You Get

### Before (Basic):
```
Title: [SYNCED] Suspicious PowerShell Activity - AutoLAW
Description:
Source Workspace: AutoLAW
Original Incident Number: 1234
Original Incident ID: abc-123
Created: 2024-11-06T10:30:00Z

---

Detected suspicious PowerShell execution on multiple hosts.
```

### After (Enhanced):
```
Title: [SYNCED] Suspicious PowerShell Activity - AutoLAW
Description:
# 🔗 Source Information
Source Workspace: AutoLAW
Original Incident #: 1234
Original Incident ID: abc-123
Source Portal Link: https://portal.azure.com/#asset/... [CLICKABLE!]
Provider: Azure Sentinel

# 📊 Incident Timeline
Created: 2024-11-06T10:30:00Z
First Activity: 2024-11-06T10:00:00Z
Last Activity: 2024-11-06T12:30:00Z

# 👥 Entities (8 total)
Accounts: 2 | Hosts: 3 | IPs: 2
Files: 0 | URLs: 0 | Processes: 1

## Top Entities (First 10):
- **Account**: admin@company.com
- **Account**: system@company.com
- **Host**: SERVER-001
- **Host**: DESKTOP-ABC
- **Host**: LAPTOP-XYZ
- **Ip**: 192.168.1.50
- **Ip**: 10.0.0.100
- **Process**: powershell.exe -enc [base64]

# 🎯 MITRE ATT&CK Tactics
Execution, DefenseEvasion

# 🚨 Alert Details
Alert Count: 3
Alert Products: Microsoft Defender for Endpoint

---

# 📝 Original Description
Detected suspicious PowerShell execution on multiple hosts.
```

**The difference is MASSIVE! 🚀**

---

**Ready to deploy? Copy `workflow-ENHANCED-ENTITIES.json` into your Logic App code view!**
