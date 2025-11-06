# Multi-Tenant Sentinel Incident Sync - CLEAN VERSION

This workspace contains a **working** Logic App that syncs Sentinel incidents across multiple tenants.

## What's Here
- `deploy.json` - ARM template (WORKS!)
- `deploy.parameters.json` - Configuration file  
- `deploy.ps1` - Deployment script
- `README.md` - Instructions

## How It Works
1. Incident created in source Sentinel → Logic App triggers
2. Gets incident details → Checks if already synced  
3. Creates `[SYNCED]` incidents in ALL target tenants
4. Prevents infinite loops with smart tagging

## Development Guidelines
- Keep it simple - no complex configurations
- One ARM template, one parameters file, one script
- Clear documentation in README
- Test with real incidents

That's it. No more complexity.
