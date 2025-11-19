param(
    [string]$apiAppNamePrefix = "apiapp",
    [string]$webAppNamePrefix = "demoapp",
    [string]$primaryRegion = "uksouth",
    [string]$secondaryRegion = "ukwest",
    [string]$appRoleName = "Api.Read.Write"
)

# $ErrorActionPreference = 'SilentlyContinue'

$assignments = @(
    @{
        Key                        = "primary"
        WebAppMIName               = "$webAppNamePrefix-$primaryRegion"
        ApiAppAuthRegistrationName = "$apiAppNamePrefix-$primaryRegion-auth"
    },
    @{
        Key                        = "secondary"
        WebAppMIName               = "$webAppNamePrefix-$secondaryRegion"
        ApiAppAuthRegistrationName = "$apiAppNamePrefix-$secondaryRegion-auth"
    }
)

foreach ($assignment in $assignments) {
    Write-Host "Assigning managed identity $($assignment.WebAppMIName) to app registration $($assignment.ApiAppAuthRegistrationName)"

    $managedIdentity = az ad sp list --filter "displayName eq '$($assignment.WebAppMIName)'" 2>&1 | ConvertFrom-Json

    $graph = az ad sp list --filter "displayName eq '$($assignment.ApiAppAuthRegistrationName)'" | ConvertFrom-Json
    $appRoleAssignmentUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($managedIdentity.id)/appRoleAssignments"

    $appRoles = @(
        $appRoleName
    )

    foreach ($appRole in $appRoles) {
        $appRoleObject = $graph.appRoles | Where-Object { $_.value -eq $appRole }
        $body = @{
            principalId = $managedIdentity.id
            resourceId  = $graph.id
            appRoleId   = $appRoleObject.id
        }
        $bodyJson = $body | ConvertTo-Json -Compress
        Write-Host "JSON Body: $bodyJson"

        Write-Host "Assigning $appRole to $($assignment.WebAppMIName)"

        $result = az rest -m POST -u $appRoleAssignmentUri --headers "Content-Type=application/json" -b $bodyJson 2>&1
    }
}

exit 0