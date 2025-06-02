#Requires -Version 5.1
<#
.SYNOPSIS
    PowerStore LUN Provisioning and Reporting Wizard
    
.DESCRIPTION
    Interactive wizard that provisions LUNs based on CSV input and generates 
    comprehensive HTML reports with progress tracking and validation.
    
.PARAMETER Silent
    Run in silent mode using existing config.json (no interactive prompts)
    
.PARAMETER ConfigFile
    Path to configuration file (default: config.json)
    
.PARAMETER InputCSV
    Path to CSV file containing LUN specifications (default: luns.csv)
    
.EXAMPLE
    .\PowerStore-Automation-Wizard.ps1
    
.EXAMPLE
    .\PowerStore-Automation-Wizard.ps1 -Silent -ConfigFile "prod_config.json" -InputCSV "production_luns.csv"
    
.NOTES
    Author: Infrastructure Team
    Version: 2.0
    Requires: PowerShell 5.1+, PowerStore REST API access
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Silent,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$InputCSV = "luns.csv"
)

# Global variables
$Script:LogFile = "PowerStore-Wizard-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').log"
$Script:PowerStoreConfig = $null
$Script:AuthHeaders = $null
$Script:BaseUri = $null
$Script:ArrayName = "PowerStore"
$Script:ProgressData = @{
    CurrentStep = 0
    TotalSteps = 10
    StepNames = @(
        "Initialisation",
        "Configuration Validation",
        "PowerStore Connection",
        "Resource Discovery",
        "CSV Validation",
        "Pre-provisioning Checks",
        "LUN Provisioning",
        "Host Mapping",
        "Post-provisioning Validation",
        "Report Generation"
    )
}

#region Helper Functions

function Write-WizardHeader {
    Clear-Host
    Write-Host @"

██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ███████╗████████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔════╝
██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝███████╗   ██║   ██║   ██║██████╔╝█████╗  
██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗╚════██║   ██║   ██║   ██║██╔══██╗██╔══╝  
██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║███████║   ██║   ╚██████╔╝██║  ██║███████╗
╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝

"@ -ForegroundColor Cyan
    
    Write-Host "                    LUN Provisioning & Reporting Wizard v2.0" -ForegroundColor White
    Write-Host "                         Enhanced with Progress Tracking" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "PROGRESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with colours
    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "PROGRESS" { Write-Host $logEntry -ForegroundColor Cyan }
    }
    
    # Write to log file
    Add-Content -Path $Script:LogFile -Value $logEntry
}

function Show-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Step,
        
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        
        [Parameter(Mandatory = $false)]
        [string]$Status = "Processing..."
    )
    
    $Script:ProgressData.CurrentStep = $Step
    $percentComplete = [math]::Round(($Step / $Script:ProgressData.TotalSteps) * 100, 1)
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $percentComplete
    
    # Console progress bar
    $barLength = 50
    $filledLength = [math]::Round(($percentComplete / 100) * $barLength)
    $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
    
    Write-Host ""
    Write-Host "Step $Step of $($Script:ProgressData.TotalSteps): $Activity" -ForegroundColor Cyan
    Write-Host "[$bar] $percentComplete%" -ForegroundColor Green
    Write-Host "Status: $Status" -ForegroundColor Gray
    Write-Host ""
    
    Write-Log "Step $Step/$($Script:ProgressData.TotalSteps): $Activity - $Status" -Level "PROGRESS"
}

function Get-UserInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        
        [Parameter(Mandatory = $false)]
        [string]$DefaultValue = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$Secure,
        
        [Parameter(Mandatory = $false)]
        [switch]$Required
    )
    
    do {
        if ($DefaultValue) {
            $displayPrompt = "$Prompt (default: $DefaultValue)"
        } else {
            $displayPrompt = $Prompt
        }
        
        if ($Secure) {
            $input = Read-Host -Prompt $displayPrompt -AsSecureString
            $input = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($input))
        } else {
            $input = Read-Host -Prompt $displayPrompt
        }
        
        if ([string]::IsNullOrWhiteSpace($input) -and $DefaultValue) {
            $input = $DefaultValue
        }
        
        if ($Required -and [string]::IsNullOrWhiteSpace($input)) {
            Write-Host "This field is required. Please provide a value." -ForegroundColor Red
        }
    } while ($Required -and [string]::IsNullOrWhiteSpace($input))
    
    return $input
}

function Test-PowerStoreConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagementIP
    )
    
    try {
        Write-Host "Testing connectivity to $ManagementIP..." -ForegroundColor Yellow
        
        # Test basic connectivity
        $tcpTest = Test-NetConnection -ComputerName $ManagementIP -Port 443 -WarningAction SilentlyContinue
        if (-not $tcpTest.TcpTestSucceeded) {
            throw "Unable to connect to $ManagementIP on port 443"
        }
        
        # Test HTTPS response
        $response = Invoke-WebRequest -Uri "https://$ManagementIP" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        
        Write-Host "✓ Connectivity test successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function New-SampleLUNCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath = "luns.csv"
    )
    
    $sampleData = @(
        [PSCustomObject]@{
            Name = "prod_web_lun_01"
            Size_GB = 1024
            Pool = "Pool0"
            Description = "Production web server storage"
            Host_Names = "webhost01;webhost02"
            Thin_Provisioned = "Yes"
            Priority = "High"
        },
        [PSCustomObject]@{
            Name = "prod_db_lun_01"
            Size_GB = 2048
            Pool = "Pool0"
            Description = "Production database storage"
            Host_Names = "dbhost01"
            Thin_Provisioned = "Yes"
            Priority = "Critical"
        },
        [PSCustomObject]@{
            Name = "dev_app_lun_01"
            Size_GB = 512
            Pool = "Pool0"
            Description = "Development application storage"
            Host_Names = "devhost01;devhost02"
            Thin_Provisioned = "Yes"
            Priority = "Medium"
        },
        [PSCustomObject]@{
            Name = "backup_lun_01"
            Size_GB = 5120
            Pool = "Pool1"
            Description = "Backup storage volume"
            Host_Names = ""
            Thin_Provisioned = "No"
            Priority = "Low"
        }
    )
    
    try {
        $sampleData | Export-Csv -Path $FilePath -NoTypeInformation
        Write-Log "Sample CSV created: $FilePath" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create sample CSV: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Import-PowerStoreConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "Configuration file not found: $ConfigPath" -Level "WARNING"
            return $null
        }
        
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded from $ConfigPath" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to load configuration: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Connect-PowerStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    try {
        # Build base URI
        $Script:BaseUri = "https://$($Config.PowerStore.ManagementIP)"
        
        # Prepare authentication
        $authBody = @{
            username = $Config.PowerStore.Username
            password = $Config.PowerStore.Password
        } | ConvertTo-Json
        
        # Skip SSL verification if specified
        if (-not $Config.PowerStore.VerifySSL) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
        
        # Authenticate
        $authParams = @{
            Uri = "$Script:BaseUri/api/rest/login_session"
            Method = "POST"
            Body = $authBody
            ContentType = "application/json"
            ErrorAction = "Stop"
        }
        
        $authResponse = Invoke-RestMethod @authParams
        
        # Set authentication headers
        $Script:AuthHeaders = @{
            "Authorization" = "Bearer $($authResponse.access_token)"
            "Content-Type" = "application/json"
        }
        
        # Get array name
        try {
            $clusters = Invoke-PowerStoreAPI -Endpoint "cluster"
            if ($clusters -and $clusters.Count -gt 0) {
                $Script:ArrayName = $clusters[0].name
            }
        }
        catch {
            Write-Log "Could not retrieve array name, using default" -Level "WARNING"
        }
        
        Write-Log "Successfully connected to PowerStore: $($Config.PowerStore.ManagementIP)" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to connect to PowerStore: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Invoke-PowerStoreAPI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method = "GET",
        
        [Parameter(Mandatory = $false)]
        [string]$Body,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$QueryParameters
    )
    
    try {
        $uri = "$Script:BaseUri/api/rest/$Endpoint"
        
        # Add query parameters if provided
        if ($QueryParameters) {
            $queryString = ($QueryParameters.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
            $uri = "$uri?$queryString"
        }
        
        $params = @{
            Uri = $uri
            Method = $Method
            Headers = $Script:AuthHeaders
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Log "API call failed - Endpoint: $Endpoint, Error: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-PowerStoreInventory {
    try {
        Write-Host "Discovering PowerStore resources..." -ForegroundColor Yellow
        
        # Get storage pools
        $pools = Invoke-PowerStoreAPI -Endpoint "storage_pool"
        $poolMap = @{}
        foreach ($pool in $pools) {
            $poolMap[$pool.name] = $pool
        }
        
        # Get hosts
        $hosts = Invoke-PowerStoreAPI -Endpoint "host"
        $hostMap = @{}
        foreach ($host in $hosts) {
            $hostMap[$host.name] = $host
        }
        
        # Get existing volumes
        $volumes = Invoke-PowerStoreAPI -Endpoint "volume"
        $volumeMap = @{}
        foreach ($volume in $volumes) {
            $volumeMap[$volume.name] = $volume
        }
        
        $inventory = @{
            Pools = $poolMap
            Hosts = $hostMap
            Volumes = $volumeMap
        }
        
        Write-Log "Discovered $($pools.Count) pools, $($hosts.Count) hosts, $($volumes.Count) volumes" -Level "SUCCESS"
        return $inventory
    }
    catch {
        Write-Log "Failed to retrieve PowerStore inventory: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-LUNRequests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$LUNRequests,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Inventory
    )
    
    $validationResults = @()
    $validCount = 0
    
    foreach ($lunRequest in $LUNRequests) {
        $validation = @{
            Name = $lunRequest.Name
            IsValid = $true
            Errors = @()
            Warnings = @()
        }
        
        # Check required fields
        if (-not $lunRequest.Name) {
            $validation.IsValid = $false
            $validation.Errors += "LUN name is required"
        }
        
        if (-not $lunRequest.Size_GB) {
            $validation.IsValid = $false
            $validation.Errors += "LUN size is required"
        }
        
        if (-not $lunRequest.Pool) {
            $validation.IsValid = $false
            $validation.Errors += "Storage pool is required"
        }
        
        # Validate pool exists
        if ($lunRequest.Pool -and -not $Inventory.Pools.ContainsKey($lunRequest.Pool)) {
            $validation.IsValid = $false
            $validation.Errors += "Storage pool '$($lunRequest.Pool)' does not exist"
        }
        
        # Check if LUN name already exists
        if ($lunRequest.Name -and $Inventory.Volumes.ContainsKey($lunRequest.Name)) {
            $validation.IsValid = $false
            $validation.Errors += "LUN name '$($lunRequest.Name)' already exists"
        }
        
        # Validate size
        if ($lunRequest.Size_GB) {
            try {
                $sizeGB = [double]$lunRequest.Size_GB
                if ($sizeGB -le 0) {
                    $validation.IsValid = $false
                    $validation.Errors += "LUN size must be greater than 0"
                }
            }
            catch {
                $validation.IsValid = $false
                $validation.Errors += "Invalid size value: $($lunRequest.Size_GB)"
            }
        }
        
        # Validate hosts if specified
        if ($lunRequest.Host_Names) {
            $hostNames = $lunRequest.Host_Names -split ";" | Where-Object { $_.Trim() }
            foreach ($hostName in $hostNames) {
                $hostName = $hostName.Trim()
                if (-not $Inventory.Hosts.ContainsKey($hostName)) {
                    $validation.Warnings += "Host '$hostName' does not exist"
                }
            }
        }
        
        # Check pool capacity (if available)
        if ($lunRequest.Pool -and $Inventory.Pools.ContainsKey($lunRequest.Pool)) {
            $pool = $Inventory.Pools[$lunRequest.Pool]
            $requestedSizeBytes = [double]$lunRequest.Size_GB * 1GB
            if ($pool.free_size -lt $requestedSizeBytes) {
                $validation.Warnings += "Requested size ($($lunRequest.Size_GB)GB) may exceed available pool capacity"
            }
        }
        
        if ($validation.IsValid) {
            $validCount++
        }
        
        $validationResults += $validation
    }
    
    Write-Log "Validation complete: $validCount valid, $($LUNRequests.Count - $validCount) invalid requests" -Level "INFO"
    return $validationResults
}

function New-PowerStoreLUN {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$LUNData,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Inventory
    )
    
    $result = @{
        Name = $LUNData.Name
        Status = "FAILED"
        Message = ""
        LUN_ID = $null
        WWN = $null
        Size_GB = $LUNData.Size_GB
        Pool = $LUNData.Pool
        Hosts_Attached = @()
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Duration = $null
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Convert size to bytes
        $sizeBytes = [long]([double]$LUNData.Size_GB * 1GB)
        
        # Get pool information
        $pool = $Inventory.Pools[$LUNData.Pool]
        
        # Prepare LUN creation request
        $createRequest = @{
            name = $LUNData.Name
            size = $sizeBytes
            description = if ($LUNData.Description) { $LUNData.Description } else { "" }
        }
        
        # Add appliance ID if available
        if ($pool.appliance_id) {
            $createRequest.appliance_id = $pool.appliance_id
        }
        
        $requestBody = $createRequest | ConvertTo-Json
        
        # Create the LUN
        Write-Host "  Creating LUN: $($LUNData.Name) ($($LUNData.Size_GB)GB)" -ForegroundColor Yellow
        $lunResponse = Invoke-PowerStoreAPI -Endpoint "volume" -Method "POST" -Body $requestBody
        
        $result.Status = "SUCCESS"
        $result.LUN_ID = $lunResponse.id
        $result.Message = "LUN created successfully"
        
        # Get LUN details to retrieve WWN
        $lunDetails = Invoke-PowerStoreAPI -Endpoint "volume/$($lunResponse.id)"
        $result.WWN = if ($lunDetails.wwn) { $lunDetails.wwn } else { "N/A" }
        
        Write-Host "  ✓ LUN created successfully - ID: $($lunResponse.id)" -ForegroundColor Green
        
        # Attach to hosts if specified
        if ($LUNData.Host_Names) {
            $hostNames = $LUNData.Host_Names -split ";" | Where-Object { $_.Trim() }
            foreach ($hostName in $hostNames) {
                $hostName = $hostName.Trim()
                if ($Inventory.Hosts.ContainsKey($hostName)) {
                    try {
                        $host = $Inventory.Hosts[$hostName]
                        
                        $mappingRequest = @{
                            volume_id = $lunResponse.id
                            host_id = $host.id
                        } | ConvertTo-Json
                        
                        Invoke-PowerStoreAPI -Endpoint "volume_host_mapping" -Method "POST" -Body $mappingRequest
                        $result.Hosts_Attached += $hostName
                        
                        Write-Host "  ✓ Attached to host: $hostName" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  ⚠ Failed to attach to host $hostName`: $($_.Exception.Message)" -ForegroundColor Yellow
                        $result.Message += " Warning: Failed to attach to host $hostName"
                    }
                }
            }
        }
    }
    catch {
        $result.Message = "Failed to create LUN: $($_.Exception.Message)"
        Write-Host "  ✗ Failed to create LUN: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed.TotalSeconds
    }
    
    return $result
}

function Start-LUNProvisioning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$LUNRequests,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Inventory
    )
    
    $results = @()
    $currentLUN = 0
    
    foreach ($lunRequest in $LUNRequests) {
        $currentLUN++
        $status = "Provisioning LUN $currentLUN of $($LUNRequests.Count): $($lunRequest.Name)"
        Show-ProgressBar -Step 7 -Activity "LUN Provisioning" -Status $status
        
        $result = New-PowerStoreLUN -LUNData $lunRequest -Inventory $Inventory
        $results += $result
        
        # Brief pause between operations
        Start-Sleep -Milliseconds 500
    }
    
    return $results
}

function New-HTMLReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ProvisioningResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Inventory,
        
        [Parameter(Mandatory = $true)]
        [array]$ValidationResults
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $reportDate = Get-Date -Format "dd/MM/yyyy"
    $reportFile = "PowerStore-Report-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').html"
    
    # Calculate statistics
    $totalRequests = $ProvisioningResults.Count
    $successful = ($ProvisioningResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
    $failed = $totalRequests - $successful
    $successRate = if ($totalRequests -gt 0) { [math]::Round(($successful / $totalRequests) * 100, 1) } else { 0 }
    
    $totalCapacityGB = ($ProvisioningResults | Where-Object { $_.Status -eq "SUCCESS" } | Measure-Object Size_GB -Sum).Sum
    $avgProvisioningTime = ($ProvisioningResults | Where-Object { $_.Duration } | Measure-Object Duration -Average).Average
    
    # Generate HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PowerStore LUN Provisioning Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f7fa; color: #333; line-height: 1.6; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; text-align: center; }
        .header h1 { font-size: 2.5rem; margin-bottom: 10px; }
        .header p { font-size: 1.1rem; opacity: 0.9; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; border-left: 4px solid #667eea; }
        .stat-value { font-size: 2rem; font-weight: bold; color: #667eea; }
        .stat-label { color: #666; margin-top: 5px; }
        .success { border-left-color: #10b981; } .success .stat-value { color: #10b981; }
        .error { border-left-color: #ef4444; } .error .stat-value { color: #ef4444; }
        .warning { border-left-color: #f59e0b; } .warning .stat-value { color: #f59e0b; }
        .section { background: white; margin-bottom: 30px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); overflow: hidden; }
        .section-header { background: #667eea; color: white; padding: 20px; font-size: 1.3rem; font-weight: 600; }
        .section-content { padding: 25px; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }
        th { background: #f8fafc; font-weight: 600; color: #374151; }
        tr:hover { background: #f8fafc; }
        .status-badge { padding: 4px 12px; border-radius: 20px; font-size: 0.85rem; font-weight: 500; }
        .status-success { background: #d1fae5; color: #065f46; }
        .status-failed { background: #fee2e2; color: #991b1b; }
        .status-warning { background: #fef3c7; color: #92400e; }
        .progress-bar { width: 100%; height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; margin: 10px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #10b981, #059669); transition: width 0.3s ease; }
        .footer { text-align: center; padding: 20px; color: #666; border-top: 1px solid #e5e7eb; margin-top: 30px; }
        .validation-error { color: #ef4444; font-size: 0.9rem; }
        .validation-warning { color: #f59e0b; font-size: 0.9rem; }
        .duration { font-family: monospace; background: #f3f4f6; padding: 2px 6px; border-radius: 4px; }
        .array-info { background: #eff6ff; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #3b82f6; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>PowerStore LUN Provisioning Report</h1>
            <p>Generated on $reportDate at $(Get-Date -Format "HH:mm:ss") | Array: $Script:ArrayName</p>
        </div>

        <div class="array-info">
            <strong>Array Information:</strong> $Script:ArrayName | 
            Storage Pools: $($Inventory.Pools.Count) | Hosts: $($Inventory.Hosts.Count) | Existing Volumes: $($Inventory.Volumes.Count)
        </div>

        <div class="stats-grid">
            <div class="stat-card success">
                <div class="stat-value">$successful</div>
                <div class="stat-label">Successful</div>
            </div>
            <div class="stat-card error">
                <div class="stat-value">$failed</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$successRate%</div>
                <div class="stat-label">Success Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$([math]::Round($totalCapacityGB, 1))GB</div>
                <div class="stat-label">Total Capacity Provisioned</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$([math]::Round($avgProvisioningTime, 2))s</div>
                <div class="stat-label">Avg. Provisioning Time</div>
            </div>
        </div>

        <div class="section">
            <div class="section-header">Provisioning Results Summary</div>
            <div class="section-content">
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $successRate%"></div>
                </div>
                <p><strong>Overall Status:</strong> $successful of $totalRequests LUNs provisioned successfully ($successRate% success rate)</p>
                
                <table>
                    <thead>
                        <tr>
                            <th>LUN Name</th>
                            <th>Size (GB)</th>
                            <th>Pool</th>
                            <th>Status</th>
                            <th>WWN</th>
                            <th>Hosts Attached</th>
                            <th>Duration</th>
                            <th>Message</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # Add provisioning results to table
    foreach ($result in $ProvisioningResults) {
        $statusClass = if ($result.Status -eq "SUCCESS") { "status-success" } else { "status-failed" }
        $hostsDisplay = if ($result.Hosts_Attached.Count -gt 0) { $result.Hosts_Attached -join ", " } else { "None" }
        $durationDisplay = if ($result.Duration) { "$([math]::Round($result.Duration, 2))s" } else { "N/A" }
        
        $htmlContent += @"
                        <tr>
                            <td><strong>$($result.Name)</strong></td>
                            <td>$($result.Size_GB)</td>
                            <td>$($result.Pool)</td>
                            <td><span class="status-badge $statusClass">$($result.Status)</span></td>
                            <td><code>$($result.WWN)</code></td>
                            <td>$hostsDisplay</td>
                            <td><span class="duration">$durationDisplay</span></td>
                            <td>$($result.Message)</td>
                        </tr>
"@
    }

    $htmlContent += @"
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="section-header">Pre-Provisioning Validation Results</div>
            <div class="section-content">
                <table>
                    <thead>
                        <tr>
                            <th>LUN Name</th>
                            <th>Validation Status</th>
                            <th>Errors</th>
                            <th>Warnings</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # Add validation results to table
    foreach ($validation in $ValidationResults) {
        $validationStatus = if ($validation.IsValid) { "Valid" } else { "Invalid" }
        $validationClass = if ($validation.IsValid) { "status-success" } else { "status-failed" }
        $errorsDisplay = if ($validation.Errors.Count -gt 0) { $validation.Errors -join "<br>" } else { "None" }
        $warningsDisplay = if ($validation.Warnings.Count -gt 0) { $validation.Warnings -join "<br>" } else { "None" }
        
        $htmlContent += @"
                        <tr>
                            <td><strong>$($validation.Name)</strong></td>
                            <td><span class="status-badge $validationClass">$validationStatus</span></td>
                            <td class="validation-error">$errorsDisplay</td>
                            <td class="validation-warning">$warningsDisplay</td>
                        </tr>
"@
    }

    $htmlContent += @"
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="section-header">Storage Pool Information</div>
            <div class="section-content">
                <table>
                    <thead>
                        <tr>
                            <th>Pool Name</th>
                            <th>Total Size (TB)</th>
                            <th>Free Size (TB)</th>
                            <th>Used (%)</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # Add storage pool information
    foreach ($pool in $Inventory.Pools.Values) {
        $totalSizeTB = [math]::Round($pool.size / 1TB, 2)
        $freeSizeTB = [math]::Round($pool.free_size / 1TB, 2)
        $usedPercent = [math]::Round((($pool.size - $pool.free_size) / $pool.size) * 100, 1)
        $poolStatus = if ($usedPercent -lt 85) { "Good" } elseif ($usedPercent -lt 95) { "Warning" } else { "Critical" }
        $poolStatusClass = if ($usedPercent -lt 85) { "status-success" } elseif ($usedPercent -lt 95) { "status-warning" } else { "status-failed" }
        
        $htmlContent += @"
                        <tr>
                            <td><strong>$($pool.name)</strong></td>
                            <td>$totalSizeTB</td>
                            <td>$freeSizeTB</td>
                            <td>$usedPercent%</td>
                            <td><span class="status-badge $poolStatusClass">$poolStatus</span></td>
                        </tr>
"@
    }

    $htmlContent += @"
                    </tbody>
                </table>
            </div>
        </div>

        <div class="section">
            <div class="section-header">Host Information</div>
            <div class="section-content">
                <table>
                    <thead>
                        <tr>
                            <th>Host Name</th>
                            <th>Operating System</th>
                            <th>Initiators</th>
                            <th>LUNs Mapped</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # Add host information
    foreach ($host in $Inventory.Hosts.Values) {
        # Get additional host details
        try {
            $hostDetails = Invoke-PowerStoreAPI -Endpoint "host/$($host.id)"
            $osType = if ($hostDetails.os_type) { $hostDetails.os_type } else { "Unknown" }
            $initiatorCount = if ($hostDetails.host_initiators) { $hostDetails.host_initiators.Count } else { 0 }
            
            # Get LUN mappings count
            $lunCount = 0
            try {
                $mappings = Invoke-PowerStoreAPI -Endpoint "volume_host_mapping" -QueryParameters @{ host_id = $host.id }
                $lunCount = if ($mappings) { $mappings.Count } else { 0 }
            }
            catch {
                $lunCount = 0
            }
            
            $hostStatus = if ($initiatorCount -gt 0) { "Active" } else { "No Initiators" }
            $hostStatusClass = if ($initiatorCount -gt 0) { "status-success" } else { "status-warning" }
        }
        catch {
            $osType = "Unknown"
            $initiatorCount = "N/A"
            $lunCount = "N/A"
            $hostStatus = "Error"
            $hostStatusClass = "status-failed"
        }
        
        $htmlContent += @"
                        <tr>
                            <td><strong>$($host.name)</strong></td>
                            <td>$osType</td>
                            <td>$initiatorCount</td>
                            <td>$lunCount</td>
                            <td><span class="status-badge $hostStatusClass">$hostStatus</span></td>
                        </tr>
"@
    }

    $htmlContent += @"
                    </tbody>
                </table>
            </div>
        </div>

        <div class="footer">
            <p>Report generated by PowerStore Automation Wizard v2.0</p>
            <p>Log file: $Script:LogFile</p>
            <p>Generation time: $timestamp</p>
        </div>
    </div>
</body>
</html>
"@

    try {
        $htmlContent | Out-File -FilePath $reportFile -Encoding UTF8
        Write-Log "HTML report generated: $reportFile" -Level "SUCCESS"
        return $reportFile
    }
    catch {
        Write-Log "Failed to generate HTML report: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

#endregion

#region Main Wizard Functions

function Start-ConfigurationWizard {
    Write-Host "Configuration Setup" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor DarkCyan
    Write-Host ""
    
    # Get PowerStore details
    do {
        $managementIP = Get-UserInput -Prompt "Enter PowerStore Management IP Address" -Required
        if (-not (Test-PowerStoreConnectivity -ManagementIP $managementIP)) {
            Write-Host "Please check the IP address and network connectivity." -ForegroundColor Red
            $retry = Get-UserInput -Prompt "Would you like to retry? (Y/N)" -DefaultValue "Y"
            if ($retry -notmatch "^[Yy]") {
                return $null
            }
        } else {
            break
        }
    } while ($true)
    
    $username = Get-UserInput -Prompt "Enter PowerStore Username" -DefaultValue "admin" -Required
    $password = Get-UserInput -Prompt "Enter PowerStore Password" -Secure -Required
    
    $verifySSL = Get-UserInput -Prompt "Verify SSL certificates? (Y/N)" -DefaultValue "N"
    $sslVerification = $verifySSL -match "^[Yy]"
    
    # Create configuration object
    $config = @{
        PowerStore = @{
            ManagementIP = $managementIP
            Username = $username
            Password = $password
            VerifySSL = $sslVerification
        }
        Logging = @{
            Level = "INFO"
            LogFile = $Script:LogFile
        }
    }
    
    # Save configuration
    try {
        $config | ConvertTo-Json -Depth 3 | Out-File -FilePath $ConfigFile -Encoding UTF8
        Write-Host "✓ Configuration saved to $ConfigFile" -ForegroundColor Green
        return $config
    }
    catch {
        Write-Host "✗ Failed to save configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-CSVFilePath {
    Write-Host ""
    Write-Host "CSV File Selection" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor DarkCyan
    Write-Host ""
    
    # Check for default CSV file
    if (Test-Path $InputCSV) {
        Write-Host "Found default CSV file: $InputCSV" -ForegroundColor Green
        $useDefault = Get-UserInput -Prompt "Use this file? (Y/N)" -DefaultValue "Y"
        if ($useDefault -match "^[Yy]") {
            return $InputCSV
        }
    } else {
        Write-Host "Default CSV file ($InputCSV) not found." -ForegroundColor Yellow
    }
    
    # Ask for custom path or create sample
    Write-Host ""
    Write-Host "Options:" -ForegroundColor White
    Write-Host "1. Specify existing CSV file path" -ForegroundColor Gray
    Write-Host "2. Create sample CSV file template" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Get-UserInput -Prompt "Choose option (1 or 2)" -DefaultValue "2"
    
    if ($choice -eq "1") {
        do {
            $csvPath = Get-UserInput -Prompt "Enter full path to CSV file" -Required
            if (Test-Path $csvPath) {
                return $csvPath
            } else {
                Write-Host "File not found: $csvPath" -ForegroundColor Red
                $retry = Get-UserInput -Prompt "Try again? (Y/N)" -DefaultValue "Y"
                if ($retry -notmatch "^[Yy]") {
                    return $null
                }
            }
        } while ($true)
    } else {
        Write-Host ""
        Write-Host "Creating sample CSV template..." -ForegroundColor Yellow
        if (New-SampleLUNCSV -FilePath $InputCSV) {
            Write-Host "✓ Sample CSV created: $InputCSV" -ForegroundColor Green
            Write-Host ""
            Write-Host "Please edit the CSV file with your LUN requirements and run the wizard again." -ForegroundColor Cyan
            Write-Host "Sample contains example LUNs with all required columns." -ForegroundColor Gray
            
            # Open CSV file if on Windows
            if ($PSVersionTable.Platform -eq "Win32NT" -or $null -eq $PSVersionTable.Platform) {
                $openFile = Get-UserInput -Prompt "Open CSV file for editing? (Y/N)" -DefaultValue "Y"
                if ($openFile -match "^[Yy]") {
                    try {
                        Start-Process notepad.exe -ArgumentList $InputCSV
                    }
                    catch {
                        Write-Host "Could not open file automatically. Please edit manually: $InputCSV" -ForegroundColor Yellow
                    }
                }
            }
            
            Write-Host ""
            Read-Host "Press Enter when you've finished editing the CSV file"
            
            if (Test-Path $InputCSV) {
                return $InputCSV
            }
        }
        return $null
    }
}

function Start-MainWizard {
    try {
        # Step 1: Initialisation
        Show-ProgressBar -Step 1 -Activity "Initialisation" -Status "Starting PowerStore wizard..."
        Write-Log "PowerStore Automation Wizard started" -Level "INFO"
        
        # Step 2: Configuration
        Show-ProgressBar -Step 2 -Activity "Configuration Validation" -Status "Loading configuration..."
        
        if ($Silent) {
            $config = Import-PowerStoreConfig -ConfigPath $ConfigFile
            if (-not $config) {
                throw "Configuration file not found or invalid: $ConfigFile"
            }
        } else {
            $config = Import-PowerStoreConfig -ConfigPath $ConfigFile
            if (-not $config) {
                Write-Host "No existing configuration found. Starting setup wizard..." -ForegroundColor Yellow
                $config = Start-ConfigurationWizard
                if (-not $config) {
                    throw "Configuration setup failed"
                }
            } else {
                Write-Host "Existing configuration found." -ForegroundColor Green
                $useExisting = Get-UserInput -Prompt "Use existing configuration? (Y/N)" -DefaultValue "Y"
                if ($useExisting -notmatch "^[Yy]") {
                    $config = Start-ConfigurationWizard
                    if (-not $config) {
                        throw "Configuration setup failed"
                    }
                }
            }
        }
        
        $Script:PowerStoreConfig = $config
        
        # Step 3: PowerStore Connection
        Show-ProgressBar -Step 3 -Activity "PowerStore Connection" -Status "Connecting to PowerStore array..."
        
        if (-not (Connect-PowerStore -Config $config)) {
            throw "Failed to connect to PowerStore"
        }
        
        # Step 4: Resource Discovery
        Show-ProgressBar -Step 4 -Activity "Resource Discovery" -Status "Discovering PowerStore resources..."
        
        $inventory = Get-PowerStoreInventory
        
        # Step 5: CSV File Handling
        Show-ProgressBar -Step 5 -Activity "CSV Validation" -Status "Loading and validating CSV file..."
        
        if (-not $Silent) {
            $csvFilePath = Get-CSVFilePath
            if (-not $csvFilePath) {
                throw "CSV file setup failed"
            }
            $InputCSV = $csvFilePath
        }
        
        if (-not (Test-Path $InputCSV)) {
            throw "CSV file not found: $InputCSV"
        }
        
        # Import LUN requests
        try {
            $lunRequests = Import-Csv $InputCSV
            Write-Log "Imported $($lunRequests.Count) LUN requests from $InputCSV" -Level "INFO"
        }
        catch {
            throw "Failed to import CSV file: $($_.Exception.Message)"
        }
        
        # Step 6: Pre-provisioning Validation
        Show-ProgressBar -Step 6 -Activity "Pre-provisioning Checks" -Status "Validating LUN requests..."
        
        $validationResults = Test-LUNRequests -LUNRequests $lunRequests -Inventory $inventory
        
        # Display validation summary
        $validCount = ($validationResults | Where-Object { $_.IsValid }).Count
        $invalidCount = $lunRequests.Count - $validCount
        
        Write-Host ""
        Write-Host "Validation Summary:" -ForegroundColor Cyan
        Write-Host "  Valid requests: $validCount" -ForegroundColor Green
        Write-Host "  Invalid requests: $invalidCount" -ForegroundColor Red
        
        if ($invalidCount -gt 0) {
            Write-Host ""
            Write-Host "Invalid LUN Requests:" -ForegroundColor Red
            foreach ($validation in $validationResults | Where-Object { -not $_.IsValid }) {
                Write-Host "  - $($validation.Name): $($validation.Errors -join ', ')" -ForegroundColor Red
            }
            
            if (-not $Silent) {
                Write-Host ""
                $proceed = Get-UserInput -Prompt "Continue with valid requests only? (Y/N)" -DefaultValue "N"
                if ($proceed -notmatch "^[Yy]") {
                    throw "Provisioning cancelled due to validation errors"
                }
            } else {
                throw "Validation errors found. Cannot proceed in silent mode."
            }
            
            # Filter to only valid requests
            $validNames = ($validationResults | Where-Object { $_.IsValid }).Name
            $lunRequests = $lunRequests | Where-Object { $_.Name -in $validNames }
        }
        
        if ($lunRequests.Count -eq 0) {
            throw "No valid LUN requests to process"
        }
        
        # Provisioning confirmation
        if (-not $Silent) {
            Write-Host ""
            Write-Host "Ready to provision $($lunRequests.Count) LUNs:" -ForegroundColor Cyan
            foreach ($lun in $lunRequests) {
                Write-Host "  - $($lun.Name) ($($lun.Size_GB)GB) on $($lun.Pool)" -ForegroundColor Gray
            }
            
            Write-Host ""
            $confirm = Get-UserInput -Prompt "Proceed with provisioning? (Y/N)" -DefaultValue "N"
            if ($confirm -notmatch "^[Yy]") {
                Write-Host "Provisioning cancelled by user." -ForegroundColor Yellow
                return
            }
        }
        
        # Step 7: LUN Provisioning
        Write-Host ""
        Write-Host "Starting LUN provisioning..." -ForegroundColor Cyan
        $provisioningResults = Start-LUNProvisioning -LUNRequests $lunRequests -Inventory $inventory
        
        # Step 8: Host Mapping (included in provisioning)
        Show-ProgressBar -Step 8 -Activity "Host Mapping" -Status "Completed during provisioning"
        Start-Sleep -Milliseconds 500
        
        # Step 9: Post-provisioning Validation
        Show-ProgressBar -Step 9 -Activity "Post-provisioning Validation" -Status "Verifying created LUNs..."
        
        # Refresh inventory to verify created LUNs
        Start-Sleep -Seconds 2
        $updatedInventory = Get-PowerStoreInventory
        
        # Step 10: Report Generation
        Show-ProgressBar -Step 10 -Activity "Report Generation" -Status "Generating comprehensive HTML report..."
        
        $reportFile = New-HTMLReport -ProvisioningResults $provisioningResults -Inventory $updatedInventory -ValidationResults $validationResults
        
        # Final Summary
        Write-Progress -Activity "Complete" -Completed
        Write-Host ""
        Write-Host "=" * 80 -ForegroundColor Green
        Write-Host "PROVISIONING COMPLETE" -ForegroundColor Green
        Write-Host "=" * 80 -ForegroundColor Green
        
        $successful = ($provisioningResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
        $failed = $provisioningResults.Count - $successful
        $successRate = [math]::Round(($successful / $provisioningResults.Count) * 100, 1)
        
        Write-Host ""
        Write-Host "Results Summary:" -ForegroundColor Cyan
        Write-Host "  Total LUN requests: $($provisioningResults.Count)" -ForegroundColor White
        Write-Host "  Successful: $successful" -ForegroundColor Green
        Write-Host "  Failed: $failed" -ForegroundColor Red
        Write-Host "  Success rate: $successRate%" -ForegroundColor White
        Write-Host ""
        
        if ($reportFile) {
            Write-Host "📊 HTML Report: $reportFile" -ForegroundColor Green
            
            # Open report if on Windows
            if (($PSVersionTable.Platform -eq "Win32NT" -or $null -eq $PSVersionTable.Platform) -and -not $Silent) {
                $openReport = Get-UserInput -Prompt "Open HTML report in browser? (Y/N)" -DefaultValue "Y"
                if ($openReport -match "^[Yy]") {
                    try {
                        Start-Process $reportFile
                    }
                    catch {
                        Write-Host "Could not open report automatically. Please open manually: $reportFile" -ForegroundColor Yellow
                    }
                }
            }
        }
        
        Write-Host "📝 Log file: $Script:LogFile" -ForegroundColor Gray
        Write-Host ""
        
        # Show failed LUNs if any
        if ($failed -gt 0) {
            Write-Host "Failed LUNs:" -ForegroundColor Red
            foreach ($result in $provisioningResults | Where-Object { $_.Status -ne "SUCCESS" }) {
                Write-Host "  ✗ $($result.Name): $($result.Message)" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        Write-Log "PowerStore Automation Wizard completed successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Wizard failed: $($_.Exception.Message)" -Level "ERROR"
        Write-Host ""
        Write-Host "❌ WIZARD FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Check log file for details: $Script:LogFile" -ForegroundColor Gray
        exit 1
    }
}

#endregion

#region Main Script Logic

# Display wizard header
Write-WizardHeader

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Log "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level "ERROR"
    exit 1
}

# Initialize logging
Write-Log "PowerStore Automation Wizard v2.0 started" -Level "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
Write-Log "Silent Mode: $Silent" -Level "INFO"

# Start the main wizard
Start-MainWizard

#endregion