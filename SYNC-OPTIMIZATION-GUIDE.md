# Sentinel Incident Sync - Optimization Guide

## 📊 What Can Be Synced?

Based on Microsoft Sentinel API capabilities, here's what you can sync:

### ✅ Currently Syncing (Basic Incident Data)
- **Title** - Incident title
- **Description** - Incident description  
- **Severity** - High/Medium/Low/Informational
- **Status** - New/Active/Closed
- **Created Time** - When incident was created
- **Incident Number** - Sequential number from source

### 🎯 Can Be Added (Rich Incident Data)

#### 1. **Entities** ⭐ HIGH VALUE
**What**: Users, IPs, hosts, files, URLs, processes involved in the incident
**Why**: Provides complete context of WHO/WHAT was involved
**How**: Use Incident Relations API
```
GET /incidents/{incidentId}/entities
```
**Value**: SOC teams can see all compromised users/systems across tenants

#### 2. **Alerts** ⭐ HIGH VALUE  
**What**: Individual security alerts that created the incident
**Why**: Shows detection rules that triggered, MITRE tactics
**How**: Use Incident Relations API
```
GET /incidents/{incidentId}/alerts
```
**Value**: Understand complete attack story with all detections

#### 3. **Comments** ⭐ MEDIUM VALUE
**What**: Analyst notes, investigation findings
**Why**: Preserve investigation context across tenants
**How**: Use Incident Comments API
```
GET /incidents/{incidentId}/comments
```
**Value**: Share investigation findings between SOC teams

#### 4. **Bookmarks** 
**What**: Saved hunting queries related to incident
**Why**: Track investigation paths
**How**: Use Incident Relations API
```
GET /incidents/{incidentId}/bookmarks
```
**Value**: Share threat hunting discoveries

#### 5. **Owner Information**
**What**: Who incident is assigned to
**Why**: Track responsibility
**How**: Already in incident properties
```json
"owner": {
  "objectId": "guid",
  "email": "analyst@company.com",
  "assignedTo": "John Doe"
}
```

#### 6. **Labels/Tags**
**What**: Custom categorization tags
**Why**: Organize incidents by campaign, asset type, etc.
**How**: Already in incident properties
```json
"labels": [
  {"labelName": "Ransomware", "labelType": "User"},
  {"labelName": "HighPriority", "labelType": "AutoAssigned"}
]
```

#### 7. **MITRE ATT&CK Tactics**
**What**: Attack techniques used
**Why**: Understand adversary behavior
**How**: In additionalData section
```json
"additionalData": {
  "tactics": ["InitialAccess", "Execution", "Persistence"]
}
```

#### 8. **Time Window**
**What**: First and last activity times
**Why**: Understand incident timeline
**How**: Already supported
```json
"firstActivityTimeUtc": "2024-11-06T10:00:00Z",
"lastActivityTimeUtc": "2024-11-06T12:30:00Z"
```

### ❌ Cannot Sync (API Limitations)
- Investigation graph state (only in portal)
- Playbook run history (separate API)
- Full entity insights (too large, dynamic)

---

## 🚀 Recommended Optimization Levels

### **Level 1: Basic Sync (Current)**
✅ Title, Description, Severity, Status  
⏱️ Simple, fast, low overhead  
👍 Good for: High-volume environments, basic alerting

### **Level 2: Enhanced Sync** ⭐ RECOMMENDED
✅ Level 1 +  
✅ Entities (users, IPs, hosts)  
✅ MITRE Tactics  
✅ Time windows  
✅ Labels  
⏱️ Moderate overhead  
👍 Good for: Most SOC teams, balanced context

### **Level 3: Full Investigation Sync**
✅ Level 2 +  
✅ Alerts (all detections)  
✅ Comments (investigation notes)  
✅ Owner assignment  
⏱️ Higher overhead, more API calls  
👍 Good for: Low-volume, high-severity incidents, cross-tenant investigations

---

## 📋 Implementation Recommendations

### Priority 1: Add Entities Sync
**Why**: Biggest ROI - SOC sees compromised users/systems immediately  
**Complexity**: Medium  
**API Calls**: +1 GET per incident  
**Value**: 🌟🌟🌟🌟🌟

**Implementation**:
```
For each incident:
  1. GET /incidents/{id}/entities
  2. Extract entity info
  3. Add to synced incident description OR
  4. Create entity relations in central workspace
```

### Priority 2: Add MITRE Tactics
**Why**: Understand attack patterns  
**Complexity**: Low (already in response)  
**API Calls**: None (included in incident GET)  
**Value**: 🌟🌟🌟🌟

**Implementation**: Already in `additionalData.tactics` - just parse and display

### Priority 3: Add Labels/Tags
**Why**: Better organization, filtering  
**Complexity**: Low  
**API Calls**: None (included in incident GET)  
**Value**: 🌟🌟🌟

**Implementation**: Copy labels array to new incident

### Priority 4: Add Alert Details
**Why**: See all detections that triggered  
**Complexity**: High  
**API Calls**: +1 GET per incident (can return 150 alerts)  
**Value**: 🌟🌟🌟🌟 (but expensive)

**Implementation**:
```
For each incident:
  1. GET /incidents/{id}/alerts (or use relations API)
  2. Create summary of alert counts by product
  3. Add to description
```

### Priority 5: Add Comments
**Why**: Share investigation findings  
**Complexity**: Medium  
**API Calls**: +1 GET, +N POST (one per comment)  
**Value**: 🌟🌟🌟

**Note**: Comments are append-only, creates history

---

## 🎛️ Configuration Options

### Option A: Metadata in Description (Simplest)
Store everything in the description field:
```
**Source:** AutoLAW
**Incident #:** 1234
**Severity:** High
**MITRE Tactics:** InitialAccess, Execution
**Entities:**
  - User: john.doe@company.com
  - IP: 192.168.1.100
  - Host: DESKTOP-ABC123
  
--- Original Description ---
[original text]
```
✅ Simple, no extra API calls  
❌ Not queryable, just text

### Option B: Structured Data via API (Advanced)
Use incident relations to create actual entity links:
```
1. Create incident
2. For each entity in source:
   - POST /incidents/{id}/relations
   - Link entity to incident
```
✅ Queryable, native Sentinel features work  
❌ Many more API calls, complex

### Option C: Hybrid (Recommended)
- Store summary in description (human-readable)
- Add top 10 entities as structured relations
- Add labels for categorization
```
Description: Human-readable summary + top entities
Labels: ["Source:AutoLAW", "Campaign:Ransomware"]
Relations: Top 10 high-value entities (users, critical IPs)
```
✅ Best of both worlds  
❌ Moderate complexity

---

## 📈 Performance Considerations

### Current Performance
- Syncs every 5 minutes
- Gets top 10 incidents per workspace
- 2 workspaces = ~20 incidents max
- 2 HTTP calls per incident (GET + PUT)
- **Total: ~40 HTTP calls per run**

### With Entities (Level 2)
- 3 HTTP calls per incident (GET incident + GET entities + PUT)
- **Total: ~60 HTTP calls per run**
- +50% overhead

### With Full Sync (Level 3)
- 5+ HTTP calls per incident (GET incident + GET entities + GET alerts + GET comments + PUT + comment POSTs)
- **Total: ~100+ HTTP calls per run**
- +150% overhead

### Throttling Limits
- Azure Management API: **12,000 reads per hour** (safe)
- Microsoft Sentinel: No specific limit documented
- **Recommendation**: Stay under 1000 API calls per 5-minute run

---

## 🔧 Quick Wins (Easy Improvements)

### 1. Add Time Windows (No extra API calls)
Already in the incident response:
```json
"firstActivityTimeUtc": "...",
"lastActivityTimeUtc": "..."
```
Just add to description.

### 2. Add MITRE Tactics (No extra API calls)
Already in `additionalData.tactics`:
```
**Tactics:** @{join(items('For_each_incident')?['properties']?['additionalData']?['tactics'], ', ')}
```

### 3. Add Labels (No extra API calls)
Already in `labels` array:
```json
"labels": "@{items('For_each_incident')?['properties']?['labels']}"
```

### 4. Add Alert Count (No extra API calls)
Already in `additionalData.alertsCount`:
```
**Alerts:** @{items('For_each_incident')?['properties']?['additionalData']?['alertsCount']}
```

---

## 🎯 Next Steps

### Immediate (No code changes needed):
1. ✅ Already syncing title, severity, status, description
2. ✅ Working Logic App deployed

### Short-term (Easy wins):
1. Add time windows to description
2. Add MITRE tactics to description  
3. Add alert count to description
4. Add labels to synced incidents

### Medium-term (More value):
1. Fetch and sync top 10 entities
2. Add entity list to description
3. Tag incidents with source workspace label

### Long-term (Advanced):
1. Sync comments for closed incidents
2. Create entity relations via API
3. Implement duplicate detection
4. Bi-directional sync (update status back to source)

---

## 💡 Recommended Next Version

Based on analysis, **Level 2 Enhanced Sync** gives best value:

**Add to current workflow**:
1. ✅ Time windows (already in response)
2. ✅ MITRE tactics (already in response)
3. ✅ Alert count (already in response)
4. ✅ Labels (already in response)
5. ➕ GET entities endpoint (+1 API call)
6. ➕ Parse top 10 entities
7. ➕ Add to description

**Total overhead**: +1 GET call per incident = ~20 extra calls per run  
**Performance impact**: Minimal (still well under limits)  
**Value increase**: 🚀 Huge! SOC gets full context immediately

---

## 🔗 API Endpoints Reference

```
Base: https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/
      providers/Microsoft.OperationalInsights/workspaces/{ws}/
      providers/Microsoft.SecurityInsights

# Incidents
GET  /incidents?api-version=2023-02-01
GET  /incidents/{id}?api-version=2023-02-01
PUT  /incidents/{id}?api-version=2023-02-01

# Entities  
GET  /incidents/{id}/entities?api-version=2023-02-01

# Relations (Alerts, Bookmarks, Entities)
GET  /incidents/{id}/relations?api-version=2023-02-01
POST /incidents/{id}/relations/{relationId}?api-version=2023-02-01

# Comments
GET  /incidents/{id}/comments?api-version=2023-02-01
POST /incidents/{id}/comments/{commentId}?api-version=2023-02-01
```

---

## ✅ Summary

| Feature | Current | Level 2 | Level 3 | API Calls | Value |
|---------|---------|---------|---------|-----------|-------|
| Title, Description, Severity | ✅ | ✅ | ✅ | 0 | ⭐⭐⭐ |
| Time Windows | ❌ | ✅ | ✅ | 0 | ⭐⭐⭐ |
| MITRE Tactics | ❌ | ✅ | ✅ | 0 | ⭐⭐⭐⭐ |
| Alert Count | ❌ | ✅ | ✅ | 0 | ⭐⭐⭐ |
| Labels | ❌ | ✅ | ✅ | 0 | ⭐⭐⭐ |
| Entities (Top 10) | ❌ | ✅ | ✅ | +1 | ⭐⭐⭐⭐⭐ |
| All Alerts | ❌ | ❌ | ✅ | +1 | ⭐⭐⭐⭐ |
| Comments | ❌ | ❌ | ✅ | +1+N | ⭐⭐⭐ |
| Owner Info | ❌ | ❌ | ✅ | 0 | ⭐⭐ |
| **Total Extra Calls** | **0** | **+1** | **+3+N** | | |

**Recommendation: Implement Level 2** 🎯
