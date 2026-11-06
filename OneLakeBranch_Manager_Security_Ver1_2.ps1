<#
===============================================================================
 Microsoft Fabric OneLake Data Access Security Automation
===============================================================================

------------------------------------------------------------------------------
 AUTHOR
------------------------------------------------------------------------------

Author:   Rakesh Sharma
Role:     Solution Engineer
Email:    rakesh.sharma@microsoft.com

------------------------------------------------------------------------------
 LICENSE
------------------------------------------------------------------------------

MIT License

Copyright (c) 2026 Rakesh Sharma

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.

IN NO EVENT SHALL THE AUTHOR OR COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
USE OR OTHER DEALINGS IN THE SOFTWARE.


------------------------------------------------------------------------------
 DISCLAIMER
------------------------------------------------------------------------------

This script is a sample/reference implementation intended to demonstrate
automation of Microsoft Fabric OneLake Data Access Security.

The script is not an official Microsoft product or supported deployment
tool.

Customers are responsible for validating the script in their own
development or test environment before using it in production.

Microsoft Fabric features, REST APIs, permissions, authentication
requirements, and supported security configurations can change over time.

Always refer to the current Microsoft Fabric documentation before using
this sample in a production environment.




.SYNOPSIS

Automates the creation or update of a Microsoft Fabric OneLake Data Access
Security role for a Fabric Lakehouse.

This sample demonstrates how Microsoft Entra security groups can be assigned
to a OneLake security role and granted controlled access to selected
Lakehouse tables and columns.

.DESCRIPTION

This PowerShell script demonstrates an automated approach for configuring
OneLake Data Access Security in Microsoft Fabric.

The sample is configured for the following scenario:

    Lakehouse:
        idfc_bharat_bank

    Schema:
        banking_gold

    Microsoft Entra Security Group:
        Fabric_IDFC_Branch_Managers

    OneLake Security Role:
        IDFCBranchManager

The script performs the following operations:

1. Authenticates to Microsoft Fabric using Microsoft Entra ID.

2. Validates that the supplied Workspace ID and Item ID identify the
   expected Microsoft Fabric Lakehouse.

3. Retrieves the existing OneLake Data Access Security role definitions
   before making any changes.

4. Preserves existing OneLake roles so that unrelated security
   configurations are not intentionally removed from the submitted
   role collection.

5. Creates the IDFCBranchManager role when the role does not already exist.

6. Updates the IDFCBranchManager role when the role already exists.

7. Assigns the Microsoft Entra security group:

       Fabric_IDFC_Branch_Managers

   to the IDFCBranchManager OneLake security role.

8. Grants Read access to the following tables:

       /Tables/banking_gold/gold_branch_performance
       /Tables/banking_gold/gold_customer_360
       /Tables/banking_gold/gold_deposit_portfolio
       /Tables/banking_gold/gold_loan_portfolio

9. Applies Column-Level Security (CLS) to:

       /Tables/banking_gold/gold_customer_360

   Only explicitly permitted columns are made available through this role.

10. Validates that the Column-Level Security tablePath exactly matches
    the corresponding table path in the role's decision rule.

11. Performs a DRY RUN by default.

    The dry run asks Microsoft Fabric to validate the proposed security
    configuration without changing the OneLake role definitions.

12. Uses the current ETag together with the If-Match HTTP header, where
    available, to reduce the risk of overwriting a newer security
    configuration created by another administrator.

13. Generates the final OneLake Data Access Security JSON payload locally
    so that administrators can inspect the proposed configuration.

14. Captures and displays the complete Microsoft Fabric REST API error
    response when validation or deployment fails.


------------------------------------------------------------------------------
 SAFETY MODEL
------------------------------------------------------------------------------

The script operates in DRY RUN mode by default.

Running:

    .\IDFC_OneLakeBranch_Manager_Security_Final.ps1 `
        -ItemId "<Lakehouse-Item-ID>"

does NOT intentionally apply the OneLake security changes.

Administrators should review:

    - The resolved Fabric Workspace
    - The resolved Lakehouse
    - Existing OneLake roles
    - Microsoft Entra security group
    - Table paths
    - Column security configuration
    - Generated JSON payload
    - Fabric dry-run response

before applying the configuration.

Changes are applied only when the administrator explicitly specifies:

    -Apply


------------------------------------------------------------------------------
 PREREQUISITES
------------------------------------------------------------------------------

Before executing this script, ensure that:

1. Microsoft Fabric is available in the target tenant.
2. OneLake Data Access Security is available for the target Fabric item.
3. Azure CLI is installed.
4. The administrator can authenticate to the required Microsoft Entra tenant.
5. The administrator has sufficient permissions to manage OneLake
   Data Access Security.
6. The required Microsoft Entra security group already exists.
7. The Workspace ID and Lakehouse Item ID have been verified.
8. Table and column names used by the script match the Fabric Lakehouse
   metadata exactly.
9. Existing OneLake roles have been reviewed before production deployment.

------------------------------------------------------------------------------
 IMPORTANT
------------------------------------------------------------------------------
The ItemId parameter represents the Microsoft Fabric ITEM ID of the
Lakehouse.

It is NOT:

    - A table Object ID
    - A Microsoft Entra Object ID
    - A security-group Object ID
    - A schema ID

Example:

    Lakehouse:
        idfc_bharat_bank

    ItemId:
        0449f987-264d-4f83-a47d-8c572ddbbaf1

------------------------------------------------------------------------------
 EXAMPLE 1 - VALIDATE ONLY
------------------------------------------------------------------------------
Runs the script in DRY RUN mode.

Microsoft Fabric validates the proposed role definition, but the script
does not intentionally apply the security changes.

.EXAMPLE

.\IDFC_OneLakeBranch_Manager_Security_Final.ps1 `
    -ItemId "0449f987-264d-4f83-a47d-8c572ddbbaf1"

------------------------------------------------------------------------------
 EXAMPLE 2 - APPLY THE CONFIGURATION
------------------------------------------------------------------------------

Run this command ONLY after the dry run has completed successfully and
the generated security configuration has been reviewed.

.EXAMPLE

.\IDFC_OneLakeBranch_Manager_Security_Final.ps1 `
    -ItemId "0449f987-264d-4f83-a47d-8c572ddbbaf1" `
    -Apply


------------------------------------------------------------------------------
 CUSTOMIZATION
------------------------------------------------------------------------------

This script is provided as a reference implementation.

Customers should modify the following values for their own environment:

    $workspaceId
    $tenantId
    $groupName
    $groupObjectId
    $RoleName
    $tablePaths
    $customer360TablePath
    $customer360AllowedColumns

Always validate customized configurations using dry-run mode before applying
changes to production environments.
===============================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ItemId,

    [switch]$Apply,

    [ValidateNotNullOrEmpty()]
    [string]$RoleName = "IDFCBranchManager"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================================
# 1. FIXED DEMO CONFIGURATION
# ============================================================================

$workspaceId = "c689eb90-e8f4-4d81-b63b-c85b78442be0"
$tenantId = "14549047-ba3b-4178-bd72-093445060a19"
$groupName = "Fabric_IDFC_Branch_Managers"
$groupObjectId = "816828dc-02cf-43be-afcf-9694c7462a5c"

# Verified OneLake location for gold_customer_360 (reference only; do NOT send these full URIs in the role JSON):
# DFS : https://onelake.dfs.fabric.microsoft.com/rsfabricworkspace/idfc_bharat_bank.Lakehouse/Tables/banking_gold/gold_customer_360
# ABFS: abfss://rsfabricworkspace@onelake.dfs.fabric.microsoft.com/idfc_bharat_bank.Lakehouse/Tables/banking_gold/gold_customer_360
# Relative OneLake path: Tables/banking_gold/gold_customer_360

# The live Fabric service rejected underscores. Enforce the live validation rule:
# role name must start with a letter and contain letters and numbers only.
if ($RoleName -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
    throw "Invalid OneLake role name '$RoleName'. The name must start with a letter and contain only letters and numbers. Example: IDFCBranchManager."
}

# PermissionScope Path values must exactly match the CLS tablePath format used below.
$tablePaths = @(
    "/Tables/banking_gold/gold_branch_performance",
    "/Tables/banking_gold/gold_customer_360",
    "/Tables/banking_gold/gold_deposit_portfolio",
    "/Tables/banking_gold/gold_loan_portfolio"
)

# CLS tablePath follows /Tables/{optionalSchema}/{tableName}.
$customer360TablePath = "/Tables/banking_gold/gold_customer_360"

# Fail locally if the CLS path is not present EXACTLY in the decision-rule paths.
# Fabric requires ColumnConstraint.tablePath to exactly match a Path value.
if ($tablePaths -notcontains $customer360TablePath) {
    throw @"
Column security configuration is invalid.
CLS tablePath: $customer360TablePath
is not present in the DecisionRule Path list.
The values must match exactly, including the leading slash, schema, table name, and casing.
"@
}

# Permit-list of columns visible to the branch-manager role.
$customer360AllowedColumns = @(
    "customer_id",
    "customer_display_name",
    "customer_segment",
    "risk_segment",
    "city",
    "state",
    "relationship_start_date",
    "kyc_status",
    "active_flag",
    "account_count",
    "total_account_balance",
    "total_available_balance",
    "fixed_deposit_count",
    "active_fd_principal",
    "loan_count",
    "total_loan_outstanding",
    "total_relationship_value"
)

$baseApiUrl = "https://api.fabric.microsoft.com/v1"
$itemUri = "$baseApiUrl/workspaces/$workspaceId/items/$ItemId"
$rolesUri = "$itemUri/dataAccessRoles"
$dryRun = -not $Apply.IsPresent

# ============================================================================
# 2. HELPER FUNCTIONS
# ============================================================================

function Get-ResponseHeaderValue {
    param(
        [Parameter(Mandatory = $true)]$Response,
        [Parameter(Mandatory = $true)][string]$Name
    )

    try {
        $value = $Response.Headers[$Name]
        if ($null -ne $value) {
            return [string]$value
        }
    }
    catch {
        # Header is not available in this PowerShell/runtime combination.
    }

    return $null
}

function Get-FabricErrorBody {
    param(
        [Parameter(Mandatory = $true)]$ErrorRecord
    )

    # PowerShell 7 commonly places the response body in ErrorDetails.Message.
    try {
        if ($null -ne $ErrorRecord.ErrorDetails) {
            $detailsMessageProperty = $ErrorRecord.ErrorDetails.PSObject.Properties["Message"]
            if ($null -ne $detailsMessageProperty) {
                $detailsMessage = [string]$detailsMessageProperty.Value
                if (-not [string]::IsNullOrWhiteSpace($detailsMessage)) {
                    return $detailsMessage
                }
            }
        }
    }
    catch {
        # Continue to response-stream fallbacks.
    }

    if ($null -eq $ErrorRecord.Exception.Response) {
        return $null
    }

    $response = $ErrorRecord.Exception.Response

    # Windows PowerShell 5.1 WebResponse path.
    try {
        if ($null -ne $response.GetResponseStream()) {
            $stream = $response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            try {
                $body = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
                $stream.Dispose()
            }

            if (-not [string]::IsNullOrWhiteSpace($body)) {
                return $body
            }
        }
    }
    catch {
        # Continue to PowerShell 7 HttpResponseMessage path.
    }

    # PowerShell 7 HttpResponseMessage path.
    try {
        if ($null -ne $response.Content) {
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if (-not [string]::IsNullOrWhiteSpace($body)) {
                return $body
            }
        }
    }
    catch {
        # No readable body was exposed by the runtime.
    }

    return $null
}

function Write-FabricFailure {
    param(
        [Parameter(Mandatory = $true)]$ErrorRecord,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "FABRIC API CALL FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Operation : $Operation"
    Write-Host "Exception : $($ErrorRecord.Exception.Message)" -ForegroundColor Red

    if ($null -ne $ErrorRecord.Exception.Response) {
        $response = $ErrorRecord.Exception.Response

        try {
            Write-Host "HTTP Status: $([int]$response.StatusCode)"
        }
        catch {
            Write-Host "HTTP Status: unavailable"
        }

        try {
            if ($null -ne $response.StatusDescription) {
                Write-Host "Description: $($response.StatusDescription)"
            }
        }
        catch {
            # StatusDescription is not exposed by every PowerShell runtime.
        }

        Write-Host ""
        Write-Host "Response headers:" -ForegroundColor Yellow
        try {
            $response.Headers | Format-List | Out-String | Write-Host
        }
        catch {
            Write-Host "Response headers could not be displayed."
        }
    }

    $errorBody = Get-FabricErrorBody -ErrorRecord $ErrorRecord

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "FABRIC ERROR RESPONSE BODY" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow

    if ([string]::IsNullOrWhiteSpace($errorBody)) {
        Write-Host "No response body was returned or exposed by this PowerShell runtime."
    }
    else {
        Write-Host $errorBody

        try {
            $errorJson = $errorBody | ConvertFrom-Json
            Write-Host ""
            Write-Host "Formatted Fabric error:" -ForegroundColor Cyan
            $errorJson | ConvertTo-Json -Depth 30 | Write-Host
        }
        catch {
            Write-Host ""
            Write-Host "The Fabric response body was not JSON." -ForegroundColor DarkYellow
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
}

function Invoke-FabricGet {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][hashtable]$Headers,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    try {
        return Invoke-WebRequest `
            -Uri $Uri `
            -Method Get `
            -Headers $Headers `
            -UseBasicParsing
    }
    catch {
        Write-FabricFailure -ErrorRecord $_ -Operation $Operation
        throw
    }
}

# ============================================================================
# 3. VERIFY PREREQUISITES AND SIGN IN
# ============================================================================

Write-Host "OneLake security automation" -ForegroundColor Cyan
Write-Host "Workspace : $workspaceId"
Write-Host "Item      : $ItemId"
Write-Host "Group     : $groupName ($groupObjectId)"
Write-Host "Role      : $RoleName"
Write-Host "Mode      : $(if ($dryRun) { 'DRY RUN' } else { 'APPLY' })" -ForegroundColor Yellow

if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI was not found. Install Azure CLI, reopen PowerShell, run az login, and retry."
}

try {
    $accountJson = az account show --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountJson)) {
        Write-Host "No active Azure CLI session. Opening sign-in..." -ForegroundColor Cyan
        az login --tenant $tenantId --allow-no-subscriptions | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI sign-in failed."
        }
    }

    $account = az account show --output json | ConvertFrom-Json
    if ([string]$account.tenantId -ne $tenantId) {
        Write-Host "Signing in to the required tenant..." -ForegroundColor Cyan
        az login --tenant $tenantId --allow-no-subscriptions | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI sign-in to tenant $tenantId failed."
        }
    }

    Write-Host "Getting Fabric access token..." -ForegroundColor Cyan
    $token = az account get-access-token `
        --tenant $tenantId `
        --resource "https://api.fabric.microsoft.com" `
        --query accessToken `
        --output tsv

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "Could not obtain a Fabric access token."
    }
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

$headers = @{
    Authorization = "Bearer $token"
    Accept = "application/json"
}

# ============================================================================
# 4. VERIFY THE TARGET FABRIC ITEM
# ============================================================================

Write-Host "Verifying Workspace and Lakehouse Item IDs..." -ForegroundColor Cyan
$itemResponse = Invoke-FabricGet `
    -Uri $itemUri `
    -Headers $headers `
    -Operation "Verify Fabric item"

try {
    $item = $itemResponse.Content | ConvertFrom-Json
}
catch {
    throw "Fabric returned an unreadable item response: $($_.Exception.Message)"
}

if ([string]$item.id -ne $ItemId) {
    throw "Fabric returned item ID '$($item.id)', but '$ItemId' was requested."
}

if ([string]$item.type -ne "Lakehouse") {
    throw "Item '$($item.displayName)' is type '$($item.type)', not Lakehouse."
}

Write-Host "Verified  : $($item.displayName) ($($item.type))" -ForegroundColor Green

# ============================================================================
# 5. RETRIEVE AND PRESERVE ALL EXISTING ROLES
# ============================================================================

Write-Host "Retrieving existing OneLake roles..." -ForegroundColor Cyan

$allExistingRoles = @()
$continuationToken = $null
$currentETag = $null

try {
    do {
        $getRolesUri = $rolesUri
        if (-not [string]::IsNullOrWhiteSpace($continuationToken)) {
            $encodedToken = [System.Uri]::EscapeDataString($continuationToken)
            $getRolesUri = "$rolesUri`?continuationToken=$encodedToken"
        }

        $rolesResponse = Invoke-WebRequest `
            -Uri $getRolesUri `
            -Method Get `
            -Headers $headers `
            -UseBasicParsing

        if ([string]::IsNullOrWhiteSpace($currentETag)) {
            $currentETag = Get-ResponseHeaderValue -Response $rolesResponse -Name "ETag"
        }

        $rolePage = $rolesResponse.Content | ConvertFrom-Json
        if ($null -ne $rolePage.value) {
            $allExistingRoles += @($rolePage.value)
        }

        $continuationToken = $null
        $continuationProperty = $rolePage.PSObject.Properties["continuationToken"]
        if ($null -ne $continuationProperty) {
            $continuationToken = [string]$continuationProperty.Value
        }
    }
    while (-not [string]::IsNullOrWhiteSpace($continuationToken))
}
catch {
    Write-FabricFailure -ErrorRecord $_ -Operation "Retrieve current OneLake roles"
    throw
}

Write-Host "Existing roles retrieved: $($allExistingRoles.Count)"
if (-not [string]::IsNullOrWhiteSpace($currentETag)) {
    Write-Host "Current ETag: $currentETag"
}

# ============================================================================
# 6. BUILD THE CORRECTED ROLE
# ============================================================================

$existingTargetRole = $allExistingRoles |
    Where-Object { [string]$_.name -eq $RoleName } |
    Select-Object -First 1

$role = [ordered]@{
    name = $RoleName
    kind = "Policy"
    decisionRules = @(
        [ordered]@{
            effect = "Permit"
            permission = @(
                [ordered]@{
                    attributeName = "Path"
                    attributeValueIncludedIn = $tablePaths
                },
                [ordered]@{
                    attributeName = "Action"
                    attributeValueIncludedIn = @("Read")
                }
            )
            constraints = [ordered]@{
                columns = @(
                    [ordered]@{
                        tablePath = $customer360TablePath
                        columnNames = $customer360AllowedColumns
                        columnEffect = "Permit"
                        columnAction = @("Read")
                    }
                )
            }
        }
    )
    members = [ordered]@{
        microsoftEntraMembers = @(
            [ordered]@{
                objectId = $groupObjectId
                objectType = "Group"
                tenantId = $tenantId
            }
        )
    }
}

# Preserve the server-assigned role ID when updating an existing role.
if ($null -ne $existingTargetRole) {
    $idProperty = $existingTargetRole.PSObject.Properties["id"]
    if ($null -ne $idProperty -and -not [string]::IsNullOrWhiteSpace([string]$idProperty.Value)) {
        $role.id = [string]$idProperty.Value
    }
    Write-Host "Role action: UPDATE existing role '$RoleName'." -ForegroundColor Yellow
}
else {
    Write-Host "Role action: CREATE new role '$RoleName'." -ForegroundColor Yellow
}

# Preserve every other existing role exactly as returned by Fabric.
$updatedRoles = @(
    $allExistingRoles |
        Where-Object { [string]$_.name -ne $RoleName }
)
$updatedRoles += $role

$bodyObject = [ordered]@{
    value = $updatedRoles
}

$body = $bodyObject | ConvertTo-Json -Depth 50

$payloadPath = Join-Path $PSScriptRoot "IDFC_OneLake_Branch_Manager_payload.json"
$body | Set-Content -Path $payloadPath -Encoding UTF8

Write-Host "Payload   : $payloadPath"
Write-Host "Role count in payload: $($updatedRoles.Count)"

# ============================================================================
# 7. BUILD THE CONDITIONAL PUT REQUEST
# ============================================================================

$putHeaders = @{
    Authorization = "Bearer $token"
    Accept = "application/json"
    "Content-Type" = "application/json"
}

if (-not [string]::IsNullOrWhiteSpace($currentETag)) {
    $etagForHeader = [string]$currentETag
    if (-not $etagForHeader.StartsWith('"') -and -not $etagForHeader.StartsWith('W/"')) {
        $etagForHeader = '"' + $etagForHeader.Trim('"') + '"'
    }
    $putHeaders["If-Match"] = $etagForHeader
}

$putUri = $rolesUri
if ($dryRun) {
    $putUri = "$rolesUri`?dryRun=true"
}
else {
    $putUri = "$rolesUri`?dryRun=false"
}

Write-Host ""
Write-Host "Endpoint  : $putUri"
Write-Host "Submitting complete role collection..." -ForegroundColor Cyan

# ============================================================================
# 8. SUBMIT, REPORT SUCCESS, OR PRINT THE COMPLETE ERROR
# ============================================================================

try {
    $response = Invoke-WebRequest `
        -Uri $putUri `
        -Method Put `
        -Headers $putHeaders `
        -Body $body `
        -ContentType "application/json" `
        -UseBasicParsing

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    if ($dryRun) {
        Write-Host "DRY RUN SUCCESSFUL" -ForegroundColor Green
        Write-Host "Fabric validated the role collection. No roles were changed."
    }
    else {
        Write-Host "ROLE COLLECTION UPDATED SUCCESSFULLY" -ForegroundColor Green
        Write-Host "The role '$RoleName' was created or updated."
    }
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "HTTP Status: $($response.StatusCode)"

    $newETag = Get-ResponseHeaderValue -Response $response -Name "ETag"
    if (-not [string]::IsNullOrWhiteSpace($newETag)) {
        Write-Host "ETag       : $newETag"
    }

    if ($dryRun) {
        Write-Host ""
        Write-Host "Next step, after reviewing the payload:" -ForegroundColor Cyan
        Write-Host ".\$($MyInvocation.MyCommand.Name) -ItemId `"$ItemId`" -Apply"
    }
}
catch {
    Write-FabricFailure -ErrorRecord $_ -Operation "Create or update OneLake data access roles"
    Write-Host "Request payload retained at: $payloadPath" -ForegroundColor Yellow
    throw
}
