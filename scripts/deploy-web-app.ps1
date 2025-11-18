<#
.SYNOPSIS
    Deploy Web App (UI) to Azure App Service
    
.DESCRIPTION
    This script builds, tests, publishes the Web UI application, and deploys it to Azure App Service.
    Based on the web-app-module6.yml pipeline.
    
.PARAMETER Environment
    Target environment (dev, test, or prod)
    
.PARAMETER Prefix
    Resource naming prefix (e.g., dotnet-vbd-m6-12345)
    
.PARAMETER BuildConfiguration
    Build configuration (Release or Debug). Default is Release.
    
.PARAMETER SkipBuild
    Skip the build, test, and publish steps
    
.PARAMETER SkipDeploy
    Skip the app service deployment
    
.EXAMPLE
    .\deploy-web-app.ps1 -Environment dev -Prefix "dotnet-vbd-m6-12345"
    
.EXAMPLE
    .\deploy-web-app.ps1 -Environment test -Prefix "dotnet-vbd-m6-12345" -SkipBuild
    
.EXAMPLE
    .\deploy-web-app.ps1 -Environment prod -Prefix "dotnet-vbd-m6-12345" -BuildConfiguration Debug
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$Prefix,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Release", "Debug")]
    [string]$BuildConfiguration = "Release",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDeploy
)

# Script variables
$ErrorActionPreference = "Stop"
$workingDirectory = Join-Path $PSScriptRoot ".." "web-app"
$outputDirectory = Join-Path $PSScriptRoot ".." "publish"
$artifactDirectory = Join-Path $outputDirectory "artifacts"
$webAppFolder = "Sample.Ui"
$webAppName = "$Prefix-$Environment-web-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Web App Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:           $Environment" -ForegroundColor Green
Write-Host "Web App:               $webAppName" -ForegroundColor Green
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
    Write-Host "`n[Step 1/3] Building, Testing, and Publishing Web Application..." -ForegroundColor Yellow
    
    # Restore dependencies
    Write-Host "Restoring NuGet packages..." -ForegroundColor White
    dotnet restore "$workingDirectory/web-app.sln"
    if ($LASTEXITCODE -ne 0) { throw "Failed to restore NuGet packages" }
    
    # Build the solution
    Write-Host "Building solution in $BuildConfiguration mode..." -ForegroundColor White
    dotnet build "$workingDirectory/web-app.sln" --configuration $BuildConfiguration --no-restore
    if ($LASTEXITCODE -ne 0) { throw "Failed to build solution" }
    
    # Check if unit tests project exists
    $unitTestsProject = Join-Path $workingDirectory "$webAppFolder.UnitTests" "$webAppFolder.UnitTests.csproj"
    if (Test-Path $unitTestsProject) {
        Write-Host "Running unit tests..." -ForegroundColor White
        dotnet test $unitTestsProject `
            --configuration $BuildConfiguration `
            --no-build `
            --logger "trx;LogFileName=unit-tests.trx"
        if ($LASTEXITCODE -ne 0) { throw "Unit tests failed" }
    }
    else {
        Write-Host "No unit tests project found, skipping..." -ForegroundColor Gray
    }
    
    # Check if integration tests project exists
    $integrationTestsProject = Join-Path $workingDirectory "$webAppFolder.IntegrationTests" "$webAppFolder.IntegrationTests.csproj"
    if (Test-Path $integrationTestsProject) {
        Write-Host "Running integration tests..." -ForegroundColor White
        dotnet test $integrationTestsProject `
            --configuration $BuildConfiguration `
            --no-build `
            --logger "trx;LogFileName=integration-tests.trx"
        if ($LASTEXITCODE -ne 0) { throw "Integration tests failed" }
    }
    else {
        Write-Host "No integration tests project found, skipping..." -ForegroundColor Gray
    }
    
    # Publish the Web application
    Write-Host "Publishing Web application..." -ForegroundColor White
    $publishPath = Join-Path $artifactDirectory $webAppFolder
    dotnet publish "$workingDirectory/$webAppFolder/$webAppFolder.csproj" `
        --configuration $BuildConfiguration `
        --no-build `
        --output $publishPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to publish Web application" }
    
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
    Write-Host "`n[Step 1/3] Skipping build step..." -ForegroundColor Gray
}
#endregion

#region Deploy Web App to App Service
if (-not $SkipDeploy) {
    Write-Host "`n[Step 2/3] Deploying Web Application to App Service..." -ForegroundColor Yellow
    
    $zipPath = Join-Path $artifactDirectory "$webAppFolder.zip"
    if (-not (Test-Path $zipPath)) {
        throw "Deployment package not found at: $zipPath. Run without -SkipBuild first."
    }
    
    # Check if logged into Azure
    Write-Host "Checking Azure login status..." -ForegroundColor White
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "Not logged into Azure. Please login..." -ForegroundColor Yellow
        az login
    }
    Write-Host "Using subscription: $($account.name)" -ForegroundColor Gray
    
    Write-Host "Deploying to App Service: $webAppName..." -ForegroundColor White
    
    # Try to get resource group from the web app
    $resourceGroup = az webapp list --query "[?name=='$webAppName'].resourceGroup" -o tsv 2>$null
    
    if ($resourceGroup) {
        Write-Host "Found resource group: $resourceGroup" -ForegroundColor Gray
        az webapp deployment source config-zip `
            --resource-group $resourceGroup `
            --name $webAppName `
            --src $zipPath
    }
    else {
        Write-Host "Warning: Could not find resource group for web app. Attempting deployment without it..." -ForegroundColor Yellow
        az webapp deployment source config-zip `
            --name $webAppName `
            --src $zipPath
    }
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to deploy to App Service" }
    
    Write-Host "✓ Web App deployed successfully" -ForegroundColor Green
    
    # Get the app URL
    if ($resourceGroup) {
        $appUrl = az webapp show `
            --resource-group $resourceGroup `
            --name $webAppName `
            --query defaultHostName `
            -o tsv
    }
    else {
        $appUrl = az webapp list --query "[?name=='$webAppName'].defaultHostName" -o tsv
    }
    
    Write-Host "`nApp URL: https://$appUrl" -ForegroundColor Cyan
}
else {
    Write-Host "`n[Step 2/3] Skipping app deployment..." -ForegroundColor Gray
}
#endregion

#region Summary
Write-Host "`n[Step 3/3] Deployment Summary" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment:           $Environment" -ForegroundColor Green
Write-Host "Web App Service:       $webAppName" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n✓ Deployment completed successfully!" -ForegroundColor Green
#endregion
