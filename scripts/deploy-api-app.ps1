<#
.SYNOPSIS
    Deploy API App to Azure App Service with database migrations
    
.DESCRIPTION
    This script builds, tests, publishes the API application, generates EF Core migrations,
    deploys the database schema, grants managed identity access, and deploys the API to Azure App Service.
    Based on the api-app-module6.yml pipeline.
    
.PARAMETER Environment
    Target environment (dev, test, or prod)
    
.PARAMETER Prefix
    Resource naming prefix (e.g., dotnet-vbd-m6-12345)
    
.PARAMETER ResourceGroupNamePrefix
    Resource group name prefix (e.g., dotnet-vbd-module6)
    
.PARAMETER BuildConfiguration
    Build configuration (Release or Debug). Default is Release.
    
.PARAMETER SkipBuild
    Skip the build, test, and publish steps
    
.PARAMETER SkipDatabaseDeploy
    Skip the database migration and user setup
    
.PARAMETER SkipAppDeploy
    Skip the app service deployment
    
.PARAMETER EnablePublicAccess
    Temporarily enable public network access to SQL Server for deployment (useful when not on private network)
    
.EXAMPLE
    .\deploy-api-app.ps1 -Environment dev -Prefix "dotnet-vbd-m6-12345" -ResourceGroupNamePrefix "dotnet-vbd-module6"
    
.EXAMPLE
    .\deploy-api-app.ps1 -Environment test -Prefix "dotnet-vbd-m6-12345" -ResourceGroupNamePrefix "dotnet-vbd-module6" -SkipBuild
#>

[CmdletBinding()]
param(
    # [Parameter(Mandatory = $true)]
    # [ValidateSet("dev", "test", "prod")]
    # [string]$Environment,
    
    # [Parameter(Mandatory = $true)]
    # [string]$Prefix,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$SqlServerName,
    
    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiAppName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Release", "Debug")]
    [string]$BuildConfiguration = "Release",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDatabaseDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAppDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnablePublicAccess
)

# Script variables
$ErrorActionPreference = "Stop"
$workingDirectory = Join-Path $PSScriptRoot ".." "api-app"
$outputDirectory = Join-Path $PSScriptRoot ".." "publish"
$artifactDirectory = Join-Path $outputDirectory "artifacts"
$webAppFolder = "Sample.Api"
# $resourceGroupName = "$ResourceGroupNamePrefix-$Environment"
# $sqlServerName = "$Prefix-$Environment-sql-server"
# $databaseName = "$Prefix-db"
# $apiAppName = "$Prefix-$Environment-api-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API App Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:           $Environment" -ForegroundColor Green
Write-Host "Resource Group:        $resourceGroupName" -ForegroundColor Green
Write-Host "SQL Server:            $sqlServerName" -ForegroundColor Green
Write-Host "Database:              $databaseName" -ForegroundColor Green
Write-Host "API App:               $apiAppName" -ForegroundColor Green
Write-Host "Build Configuration:   $BuildConfiguration" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Create output directories
if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
if (-not (Test-Path $artifactDirectory)) {
    New-Item -ItemType Directory -Path $artifactDirectory | Out-Null
}

#region Build, Test, and Publish
if (-not $SkipBuild) {
    Write-Host "`n[Step 1/5] Building, Testing, and Publishing API Application..." -ForegroundColor Yellow
    
    # Restore dependencies
    Write-Host "Restoring NuGet packages..." -ForegroundColor White
    dotnet restore "$workingDirectory/api-app.sln"
    if ($LASTEXITCODE -ne 0) { throw "Failed to restore NuGet packages" }
    
    # Build the solution
    Write-Host "Building solution in $BuildConfiguration mode..." -ForegroundColor White
    dotnet build "$workingDirectory/api-app.sln" --configuration $BuildConfiguration --no-restore
    if ($LASTEXITCODE -ne 0) { throw "Failed to build solution" }
    
    # Run unit tests
    Write-Host "Running unit tests..." -ForegroundColor White
    dotnet test "$workingDirectory/Sample.Api.UnitTests/Sample.Api.UnitTests.csproj" `
        --configuration $BuildConfiguration `
        --no-build `
        --logger "trx;LogFileName=unit-tests.trx"
    if ($LASTEXITCODE -ne 0) { throw "Unit tests failed" }
    
    # Run integration tests
    <#     Write-Host "Running integration tests..." -ForegroundColor White
    dotnet test "$workingDirectory/Sample.Api.IntegrationTests/Sample.Api.IntegrationTests.csproj" `
        --configuration $BuildConfiguration `
        --no-build `
        --logger "trx;LogFileName=integration-tests.trx"
    if ($LASTEXITCODE -ne 0) { throw "Integration tests failed" } #>
    
    # Publish the API application
    Write-Host "Publishing API application..." -ForegroundColor White
    $publishPath = Join-Path $artifactDirectory $webAppFolder
    dotnet publish "$workingDirectory/$webAppFolder/$webAppFolder.csproj" `
        --configuration $BuildConfiguration `
        --no-build `
        --output $publishPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to publish API application" }
    
    # Create deployment package (zip)
    Write-Host "Creating deployment package..." -ForegroundColor White
    $zipPath = Join-Path $artifactDirectory "$webAppFolder.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    Compress-Archive -Path "$publishPath/*" -DestinationPath $zipPath
    
    Write-Host "✓ Build and publish completed successfully" -ForegroundColor Green
}
else {
    Write-Host "`n[Step 1/5] Skipping build step..." -ForegroundColor Gray
}
#endregion

#region Generate Database Migration Script
if (-not $SkipBuild -and -not $SkipDatabaseDeploy) {
    Write-Host "`n[Step 2/5] Generating Database Migration Script..." -ForegroundColor Yellow
    
    # Install EF Core tools if not already installed
    Write-Host "Ensuring Entity Framework tools are installed..." -ForegroundColor White
    dotnet tool install --global dotnet-ef 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "EF Core tools already installed or updated" -ForegroundColor Gray
    }
    
    # Generate idempotent SQL migration script
    Write-Host "Generating idempotent SQL migration script..." -ForegroundColor White
    $migrationScriptPath = Join-Path $artifactDirectory "migrations.sql"
    dotnet ef migrations script --idempotent --project "$workingDirectory/$webAppFolder" --output $migrationScriptPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate migration script" }
    
    Write-Host "✓ Migration script generated: $migrationScriptPath" -ForegroundColor Green
}
else {
    Write-Host "`n[Step 2/5] Skipping migration script generation..." -ForegroundColor Gray
}
#endregion

#region Deploy Database Updates
if (-not $SkipDatabaseDeploy) {
    Write-Host "`n[Step 3/5] Deploying Database Updates..." -ForegroundColor Yellow
    
    $migrationScriptPath = Join-Path $artifactDirectory "migrations.sql"
    if (-not (Test-Path $migrationScriptPath)) {
        throw "Migration script not found at: $migrationScriptPath. Run without -SkipBuild first."
    }
    
    # Check if logged into Azure
    Write-Host "Checking Azure login status..." -ForegroundColor White
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "Not logged into Azure. Please login..." -ForegroundColor Yellow
        az login
    }
    Write-Host "Using subscription: $($account.name)" -ForegroundColor Gray
    
    # Optionally enable public access for deployment
    $firewallRuleName = "TempDeploymentRule-$(Get-Date -Format 'yyyyMMddHHmmss')"
    if ($EnablePublicAccess) {
        Write-Host "Enabling public network access to SQL Server..." -ForegroundColor White
        $currentIP = (Invoke-RestMethod https://api.ipify.org/?format=json).ip
        Write-Host "Current IP: $currentIP" -ForegroundColor Gray
        
        az sql server update `
            --resource-group $resourceGroupName `
            --name $sqlServerName `
            --enable-public-network true
        
        az sql server firewall-rule create `
            --resource-group $resourceGroupName `
            --server $sqlServerName `
            --name $firewallRuleName `
            --start-ip-address $currentIP `
            --end-ip-address $currentIP
        
        Write-Host "Waiting for firewall rule to propagate..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
    
    try {
        # Get access token for SQL Database
        Write-Host "Getting Azure AD access token..." -ForegroundColor White
        $accessToken = az account get-access-token --resource=https://database.windows.net/ --query accessToken -o tsv
        if (-not $accessToken) { throw "Failed to get access token" }
        
        # Install SqlServer module if not present
        Write-Host "Ensuring SqlServer PowerShell module is installed..." -ForegroundColor White
        if (-not (Get-Module -ListAvailable -Name SqlServer)) {
            Install-Module -Name SqlServer -Force -Scope CurrentUser -AllowClobber
        }
        Import-Module SqlServer
        
        # Run migration script
        Write-Host "Running database migration script..." -ForegroundColor White
        $sqlServerFqdn = "$sqlServerName.database.windows.net"
        Invoke-Sqlcmd `
            -InputFile $migrationScriptPath `
            -ServerInstance $sqlServerFqdn `
            -Database $databaseName `
            -AccessToken $accessToken `
            -ConnectionTimeout 30 `
            -QueryTimeout 300
        
        Write-Host "✓ Database schema updated successfully" -ForegroundColor Green
        
        # Grant managed identity access to database
        Write-Host "Granting API App Managed Identity access to database..." -ForegroundColor White
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = "Server=tcp:$sqlServerFqdn,1433;Database=$databaseName;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;"
        $conn.AccessToken = $accessToken
        
        $apiAppUsername = $apiAppName
        $query = @"
            IF NOT EXISTS (SELECT name FROM [sys].[database_principals] WHERE name = N'$apiAppUsername')
            BEGIN
                CREATE USER [$apiAppUsername] FROM EXTERNAL PROVIDER;
                ALTER ROLE db_datareader ADD MEMBER [$apiAppUsername];
                ALTER ROLE db_datawriter ADD MEMBER [$apiAppUsername];
                ALTER ROLE db_ddladmin ADD MEMBER [$apiAppUsername];
            END
"@
        
        Write-Host "Connecting to SQL Database..." -ForegroundColor White
        $retryCount = 0
        $maxRetries = 12
        while ($conn.State -ne "Open" -and $retryCount -lt $maxRetries) {
            try {
                $conn.Open()
            }
            catch {
                $retryCount++
                Write-Host "Waiting for SQL to be ready (attempt $retryCount/$maxRetries)..." -ForegroundColor Gray
                Start-Sleep -Seconds 5
            }
        }
        
        if ($conn.State -ne "Open") {
            throw "Failed to connect to SQL Database after $maxRetries attempts"
        }
        
        Write-Host "Executing user grant script..." -ForegroundColor White
        $command = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
        $result = $command.ExecuteNonQuery()
        $conn.Close()
        
        Write-Host "✓ Managed identity access granted successfully" -ForegroundColor Green
    }
    finally {
        # Clean up firewall rule if it was created
        if ($EnablePublicAccess) {
            Write-Host "Removing temporary firewall rule..." -ForegroundColor White
            az sql server firewall-rule delete `
                --resource-group $resourceGroupName `
                --server $sqlServerName `
                --name $firewallRuleName 2>$null
            
            az sql server update `
                --resource-group $resourceGroupName `
                --name $sqlServerName `
                --enable-public-network false
            
            Write-Host "✓ Firewall rule removed" -ForegroundColor Green
        }
    }
}
else {
    Write-Host "`n[Step 3/5] Skipping database deployment..." -ForegroundColor Gray
}
#endregion

#region Deploy API App to App Service
if (-not $SkipAppDeploy) {
    Write-Host "`n[Step 4/5] Deploying API Application to App Service..." -ForegroundColor Yellow
    
    $zipPath = Join-Path $artifactDirectory "$webAppFolder.zip"
    if (-not (Test-Path $zipPath)) {
        throw "Deployment package not found at: $zipPath. Run without -SkipBuild first."
    }
    
    Write-Host "Deploying to App Service: $apiAppName..." -ForegroundColor White
    az webapp deployment source config-zip `
        --resource-group $resourceGroupName `
        --name $apiAppName `
        --src $zipPath
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to deploy to App Service" }
    
    Write-Host "✓ API App deployed successfully" -ForegroundColor Green
    
    # Get the app URL
    $appUrl = az webapp show `
        --resource-group $resourceGroupName `
        --name $apiAppName `
        --query defaultHostName `
        -o tsv
    
    Write-Host "`nApp URL: https://$appUrl" -ForegroundColor Cyan
}
else {
    Write-Host "`n[Step 4/5] Skipping app deployment..." -ForegroundColor Gray
}
#endregion

#region Summary
Write-Host "`n[Step 5/5] Deployment Summary" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:           $Environment" -ForegroundColor Green
Write-Host "Resource Group:        $resourceGroupName" -ForegroundColor Green
Write-Host "API App Service:       $apiAppName" -ForegroundColor Green
Write-Host "SQL Server:            $sqlServerName" -ForegroundColor Green
Write-Host "Database:              $databaseName" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n✓ Deployment completed successfully!" -ForegroundColor Green
#endregion
