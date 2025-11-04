# Microsoft Sentinel Multi-Tenant Logic App Project

This workspace contains a Logic App solution for synchronizing Sentinel incidents across multiple Azure tenants using Azure Lighthouse.

## Project Context
- **Purpose**: Cross-tenant incident synchronization for Microsoft Sentinel
- **Technology**: Azure Logic Apps, Azure Lighthouse, Microsoft Sentinel API
- **Architecture**: Multi-tenant SIEM with centralized incident management

## Development Guidelines
- Follow Azure best practices for Logic Apps
- Use managed identities for authentication
- Implement proper error handling and retry logic
- Keep configuration separate from code
- Document all API connections and permissions required

## Required Permissions
- Microsoft Sentinel Contributor on delegated subscriptions
- Logic App Contributor on main subscription
- Managed Identity with appropriate API permissions
