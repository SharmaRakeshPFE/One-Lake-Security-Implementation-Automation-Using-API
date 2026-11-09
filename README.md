# Microsoft Fabric OneLake Data Access Security Automation

A customer-neutral reference repository for validating and deploying a Microsoft Fabric OneLake data access role by using PowerShell, Azure CLI, and the Microsoft Fabric REST API.

Disclaimer: The name “IDFC” is used in this document solely for illustrative and demonstration purposes. This solution does not use, access, process, or represent any actual data belonging to IDFC Bank. All scenarios, configurations, and examples are intended exclusively to demonstrate Microsoft Fabric Onelake security automation and do not imply any association with or endorsement by IDFC Bank.

> **Anonymization note:** Customer names, tenant identifiers, workspace identifiers, item identifiers, security-group identifiers, environment names, local paths, and captured outputs have been replaced with `XXXX`.

## Repository contents

- `scripts/Deploy-OneLakeDataAccessRole.ps1` - dry-run-first deployment script.
- `docs/OneLake_Data_Access_Security_Implementation_Guide.docx` - customer-ready implementation guide.
- `examples/parameters.example.psd1` - placeholder configuration sample.
- `LICENSE` - MIT license.

## Safety model

1. Review and replace every `XXXX` placeholder in a private working copy.
2. Run the script without `-Apply` to invoke Fabric validation with `dryRun=true`.
3. Review the generated JSON payload and current role collection.
4. Use `-Apply` only after validation succeeds.

## Prerequisites

- Microsoft Fabric workspace and Lakehouse.
- OneLake Data Access Security enabled for the target item.
- PowerShell 7.
- Azure CLI.
- Microsoft Entra security group.
- Administrator permissions required to manage OneLake roles.

## Example

```powershell
.\scripts\Deploy-OneLakeDataAccessRole.ps1 -ItemId "XXXX"
.\scripts\Deploy-OneLakeDataAccessRole.ps1 -ItemId "XXXX" -Apply
```

## Important

This is a sample implementation. Validate it in a development or test environment and review current Microsoft Fabric documentation before production use.


#Refrences:

Microsoft Learn: Create or Update Data Access Roles 
https://learn.microsoft.com/en-us/rest/api/fabric/core/onelake-data-access-security/create-or-update-data-access-roles
Endpoint: PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/items/{itemId}/dataAccessRoles
For validation: PUT https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/items/{itemId}/dataAccessRoles?dryRun=true
https://learn.microsoft.com/en-us/rest/api/fabric/core/onelake-data-access-security
