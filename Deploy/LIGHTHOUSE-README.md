# Azure Lighthouse Delegation for Multi-Tenant Sentinel

This template enables your Logic App's managed identity to access **customer tenants** for centralized Sentinel incident monitoring.

## 🎯 **When to Use This**

Use Azure Lighthouse when you have:
- **Multiple Azure AD tenants** (different customers/organizations)  
- **Customer workspaces** you need to monitor
- Need for **centralized cross-tenant management**

## 📋 **Current Setup vs. Lighthouse**

### **Current Logic App (Same Tenant)**
```json
{
  "remoteWorkspaces": [
    {
      "name": "AutoLAW",
      "subscriptionId": "7d727b43-c480-4637-9b2d-f53db5982220",
      "resourceGroup": "autorg1", 
      "workspace": "AutoLAW"
    }
  ]
}
```
✅ **Works now** - Same tenant, direct permissions

### **With Lighthouse (Cross-Tenant)**
```json
{
  "remoteWorkspaces": [
    {
      "name": "Customer-A-Sentinel",
      "subscriptionId": "customer-a-subscription-id",
      "resourceGroup": "rg-customer-a-sentinel",
      "workspace": "customer-a-workspace"
    },
    {
      "name": "Customer-B-Sentinel", 
      "subscriptionId": "customer-b-subscription-id",
      "resourceGroup": "rg-customer-b-sentinel",
      "workspace": "customer-b-workspace"
    }
  ]
}
```
✅ **Requires Lighthouse** - Different tenants, delegated access

---

## 🚀 **Deployment Instructions**

### **Step 1: Deploy in Each Customer Tenant**

Run this in **each customer's Azure tenant** that you want to monitor:

```powershell
# Connect to customer tenant
Connect-AzAccount -TenantId "customer-tenant-id"

# Deploy the delegation  
.\Deploy-Lighthouse.ps1 -SubscriptionId "customer-subscription-id" -CustomerTenantName "Customer A"
```

### **Step 2: Update Logic App Configuration**

After Lighthouse delegation, add the customer workspaces to your Logic App parameters:

```json
{
  "remoteWorkspaces": {
    "value": [
      {
        "name": "AutoLAW",
        "subscriptionId": "7d727b43-c480-4637-9b2d-f53db5982220", 
        "resourceGroup": "autorg1",
        "workspace": "AutoLAW"
      },
      {
        "name": "Customer-A-Sentinel",
        "subscriptionId": "customer-a-sub-id",
        "resourceGroup": "rg-customer-a-sentinel", 
        "workspace": "customer-a-workspace"
      }
    ]
  }
}
```

---

## 🔑 **Permissions Granted**

The Lighthouse delegation grants your Logic App's managed identity:

| Role | Purpose |
|------|---------|
| **Owner** | Full access to manage resources |
| **Microsoft Sentinel Reader** | Read incidents, entities, and analytics |
| **Microsoft Sentinel Responder** | Create/update incidents, manage cases |

## 🏗️ **Template Details**

### **Key Components**

- **Registration Definition**: Defines what access is delegated
- **Registration Assignment**: Actually delegates the access  
- **Managed Identity**: `81f2b226-a50a-4054-9bdb-b9657c2a390d`
- **Application ID**: `a1a3c76e-3703-4b2f-813f-fc3469237773`

### **Managing Tenant Info**
- **Tenant ID**: `dcfeeacc-5825-4e13-8238-d7b052837b25`
- **Display Name**: Central Security Operations

---

## ✅ **Verification**

After deployment, verify the delegation:

1. **In Azure Portal** (customer tenant):
   - Navigate to **Service providers** 
   - Look for "Multi-Tenant Sentinel Monitoring"

2. **In Managing Tenant**:
   - Navigate to **My customers**
   - See delegated customer subscriptions

3. **Test Logic App**:
   - Add customer workspace to parameters
   - Run manually to test cross-tenant access

---

## 🔄 **Removing Delegation**

To remove access:

```powershell
# In customer tenant
Remove-AzManagedServicesAssignment -Id "/subscriptions/{subscription-id}/providers/Microsoft.ManagedServices/registrationAssignments/{assignment-id}"
```

---

## 📞 **Support**

The Logic App managed identity will have access to:
- ✅ Read incidents from customer Sentinel workspaces
- ✅ Create synced incidents in central workspace  
- ✅ Manage incident lifecycle and responses
- ✅ Access entities and analytics data

Perfect for **MSP scenarios** and **multi-customer SOC operations**! 🎯