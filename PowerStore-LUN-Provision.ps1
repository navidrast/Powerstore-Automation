#Requires -Version 5.1
<#
.SYNOPSIS
    PowerStore LUN Provisioning Script
    
.DESCRIPTION
    This script provisions LUNs on Dell PowerStore arrays based on a CSV input file
    and generates detailed reports similar to the data structure found in your exports.
    
.PARAMETER ConfigFile
    Path to configuration file containing PowerStore connection details
    
.PARAMETER InputCSV
    Path to CSV file containing LUN specifications
    
.PARAMETER OutputReport
    Path for output CSV report file
    
.PARAMETER GetInventory
    Switch to retrieve current LUN inventory
    
.PARAMETER CreateSampleCSV
    Switch to create sample CSV template
    
.PARAMETER CreateSampleConfig
    Switch to create sample configuration file
    
.EXAMPLE
    .\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -InputCSV "luns.csv" -OutputReport "report.csv"
    
.EXAMPLE
    .\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -GetInventory
    
.NOTES
    Author: Infrastructure Team
    Version: 1.0
    Requires: PowerShell 5.1+, PowerStore REST API access
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$InputCSV,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputReport,
    
    [Parameter(Mandatory = $false)]
    [switch]$GetInventory,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateSampleCSV,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateSampleConfig
)

# Global variables
$Script:LogFile = "PowerStore-Provision-$(Get-Date -Format 'yyyy-MM-dd').log"
$Script:PowerStoreConfig = $null
$Script:AuthHeaders = $null
$Script:BaseUri = $null

#region Helper Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $Script:LogFile -Value $logEntry
}

function Test-PowerShellVersion {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level "ERROR"
        return $false
    }
    return $true
}

function Import-ConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "Configuration file not found: $ConfigPath" -Level "ERROR"
            return $null
        }
        
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully from $ConfigPath" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to load configuration file: $($_.Exception.Message)" -Level "ERROR"
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

function Get-PowerStoreHosts {
    try {
        $hosts = Invoke-PowerStoreAPI -Endpoint "host"
        $hostMap = @{}
        
        foreach ($host in $hosts) {
            $hostMap[$host.name] = $host
        }
        
        Write-Log "Cached $($hosts.Count) PowerStore hosts" -Level "INFO"
        return $hostMap
    }
    catch {
        Write-Log "Failed to retrieve PowerStore hosts: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-PowerStorePools {
    try {
        $pools = Invoke-PowerStoreAPI -Endpoint "storage_pool"
        $poolMap = @{}
        
        foreach ($pool in $pools) {
            $poolMap[$pool.name] = $pool
        }
        
        Write-Log "Cached $($pools.Count) PowerStore storage pools" -Level "INFO"
        return $poolMap
    }
    catch {
        Write-Log "Failed to retrieve PowerStore storage pools: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-LUNRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$LUNData,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$PoolMap,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$HostMap
    )
    
    # Check required fields
    if (-not $LUNData.Name -or -not $LUNData.Size_GB -or -not $LUNData.Pool) {
        return @{
            IsValid = $false
            ErrorMessage = "Missing required fields: Name, Size_GB, or Pool"
        }
    }
    
    # Validate pool exists
    if (-not $PoolMap.ContainsKey($LUNData.Pool)) {
        return @{
            IsValid = $false
            ErrorMessage = "Storage pool '$($LUNData.Pool)' does not exist"
        }
    }
    
    # Validate size
    try {
        $sizeGB = [double]$LUNData.Size_GB
        if ($sizeGB -le 0) {
            return @{
                IsValid = $false
                ErrorMessage = "Size must be greater than 0"
            }
        }
    }
    catch {
        return @{
            IsValid = $false
            ErrorMessage = "Invalid size value: $($LUNData.Size_GB)"
        }
    }
    
    # Validate hosts if specified
    if ($LUNData.Host_Names) {
        $hostNames = $LUNData.Host_Names -split ";" | Where-Object { $_.Trim() }
        foreach ($hostName in $hostNames) {
            $hostName = $hostName.Trim()
            if (-not $HostMap.ContainsKey($hostName)) {
                return @{
                    IsValid = $false
                    ErrorMessage = "Host '$hostName' does not exist"
                }
            }
        }
    }
    
    return @{
        IsValid = $true
        ErrorMessage = ""
    }
}

function New-PowerStoreLUN {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$LUNData,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$PoolMap,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$HostMap
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
    }
    
    try {
        # Convert size to bytes
        $sizeBytes = [long]([double]$LUNData.Size_GB * 1GB)
        
        # Get pool information
        $pool = $PoolMap[$LUNData.Pool]
        
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
        Write-Log "Creating LUN: $($LUNData.Name)"
        $lunResponse = Invoke-PowerStoreAPI -Endpoint "volume" -Method "POST" -Body $requestBody
        
        $result.Status = "SUCCESS"
        $result.LUN_ID = $lunResponse.id
        $result.Message = "LUN created successfully"
        
        # Get LUN details to retrieve WWN
        $lunDetails = Invoke-PowerStoreAPI -Endpoint "volume/$($lunResponse.id)"
        $result.WWN = if ($lunDetails.wwn) { $lunDetails.wwn } else { "N/A" }
        
        Write-Log "Successfully created LUN $($LUNData.Name) with ID $($lunResponse.id)" -Level "SUCCESS"
        
        # Attach to hosts if specified
        if ($LUNData.Host_Names) {
            $hostNames = $LUNData.Host_Names -split ";" | Where-Object { $_.Trim() }
            foreach ($hostName in $hostNames) {
                $hostName = $hostName.Trim()
                try {
                    $host = $HostMap[$hostName]
                    
                    $mappingRequest = @{
                        volume_id = $lunResponse.id
                        host_id = $host.id
                    } | ConvertTo-Json
                    
                    Invoke-PowerStoreAPI -Endpoint "volume_host_mapping" -Method "POST" -Body $mappingRequest
                    $result.Hosts_Attached += $hostName
                    
                    Write-Log "Attached LUN $($LUNData.Name) to host $hostName" -Level "SUCCESS"
                }
                catch {
                    Write-Log "Failed to attach LUN $($LUNData.Name) to host $hostName`: $($_.Exception.Message)" -Level "WARNING"
                    $result.Message += " Warning: Failed to attach to host $hostName"
                }
            }
        }
    }
    catch {
        $result.Message = "Failed to create LUN: $($_.Exception.Message)"
        Write-Log "Failed to create LUN $($LUNData.Name): $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $result
}

function Get-PowerStoreLUNInventory {
    try {
        Write-Log "Retrieving PowerStore LUN inventory..."
        
        # Get all volumes
        $volumes = Invoke-PowerStoreAPI -Endpoint "volume"
        
        $inventory = @()
        foreach ($volume in $volumes) {
            try {
                # Get volume details
                $volumeDetails = Invoke-PowerStoreAPI -Endpoint "volume/$($volume.id)"
                
                # Get host mappings
                $mappings = @()
                try {
                    $mappings = Invoke-PowerStoreAPI -Endpoint "volume_host_mapping" -QueryParameters @{ volume_id = $volume.id }
                }
                catch {
                    # Host mappings might not exist
                }
                
                $inventoryItem = [PSCustomObject]@{
                    "!" = "OK"
                    "Name" = $volume.name
                    "Size_GB" = [math]::Round($volume.size / 1GB, 2)
                    "Allocated_Percent" = if ($volumeDetails.allocated_percent) { $volumeDetails.allocated_percent } else { 0 }
                    "Pool" = if ($volumeDetails.storage_pool) { $volumeDetails.storage_pool.name } else { "Unknown" }
                    "Type" = "LUN"
                    "Description" = if ($volume.description) { $volume.description } else { "" }
                    "Hosts" = $mappings.Count
                    "Replication_Type" = if ($volumeDetails.replication_role) { $volumeDetails.replication_role } else { "None" }
                    "Thin" = if ($volumeDetails.is_thin_enabled) { "Yes" } else { "No" }
                    "WWN" = if ($volumeDetails.wwn) { $volumeDetails.wwn } else { "" }
                    "Thin_Clone_Base" = "--"
                    "Status" = if ($volume.state) { $volume.state } else { "Unknown" }
                }
                
                $inventory += $inventoryItem
            }
            catch {
                Write-Log "Failed to get details for volume $($volume.name): $($_.Exception.Message)" -Level "WARNING"
                
                $inventoryItem = [PSCustomObject]@{
                    "!" = "Warning"
                    "Name" = $volume.name
                    "Size_GB" = [math]::Round($volume.size / 1GB, 2)
                    "Status" = "Details unavailable"
                }
                
                $inventory += $inventoryItem
            }
        }
        
        Write-Log "Retrieved inventory for $($inventory.Count) LUNs" -Level "SUCCESS"
        return $inventory
    }
    catch {
        Write-Log "Failed to retrieve LUN inventory: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Import-LUNRequestsFromCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CSVPath
    )
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "CSV file not found: $CSVPath" -Level "ERROR"
            return $null
        }
        
        $lunRequests = Import-Csv $CSVPath
        Write-Log "Imported $($lunRequests.Count) LUN requests from $CSVPath" -Level "INFO"
        return $lunRequests
    }
    catch {
        Write-Log "Failed to import CSV file: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Export-ProvisioningReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    try {
        # Convert results to CSV format
        $csvResults = @()
        foreach ($result in $Results) {
            $csvResult = [PSCustomObject]@{
                Name = $result.Name
                Status = $result.Status
                Message = $result.Message
                LUN_ID = $result.LUN_ID
                WWN = $result.WWN
                Size_GB = $result.Size_GB
                Pool = $result.Pool
                Hosts_Attached = ($result.Hosts_Attached -join ";")
                Timestamp = $result.Timestamp
            }
            $csvResults += $csvResult
        }
        
        # Display summary
        $total = $Results.Count
        $successful = ($Results | Where-Object { $_.Status -eq "SUCCESS" }).Count
        $failed = $total - $successful
        $successRate = if ($total -gt 0) { [math]::Round(($successful / $total) * 100, 1) } else { 0 }
        
        Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
        Write-Host "PowerStore LUN Provisioning Report" -ForegroundColor Cyan
        Write-Host "=" * 60 -ForegroundColor Cyan
        Write-Host "Total LUN requests: $total" -ForegroundColor White
        Write-Host "Successful: $successful" -ForegroundColor Green
        Write-Host "Failed: $failed" -ForegroundColor Red
        Write-Host "Success rate: $successRate%" -ForegroundColor White
        Write-Host "=" * 60 -ForegroundColor Cyan
        
        # Display detailed results
        foreach ($result in $Results) {
            $symbol = if ($result.Status -eq "SUCCESS") { "✓" } else { "✗" }
            $color = if ($result.Status -eq "SUCCESS") { "Green" } else { "Red" }
            
            Write-Host "$symbol $($result.Name) - $($result.Status)" -ForegroundColor $color
            
            if ($result.Message) {
                Write-Host "  Message: $($result.Message)" -ForegroundColor Gray
            }
            if ($result.WWN) {
                Write-Host "  WWN: $($result.WWN)" -ForegroundColor Gray
            }
            if ($result.Hosts_Attached -and $result.Hosts_Attached.Count -gt 0) {
                Write-Host "  Attached to hosts: $($result.Hosts_Attached -join ', ')" -ForegroundColor Gray
            }
        }
        
        # Export to CSV if path provided
        if ($OutputPath) {
            $csvResults | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Log "Provisioning report exported to: $OutputPath" -Level "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to export provisioning report: $($_.Exception.Message)" -Level "ERROR"
    }
}

function New-SampleCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath = "sample_luns.csv"
    )
    
    $sampleData = @(
        [PSCustomObject]@{
            Name = "app_data_lun_01"
            Size_GB = 1024
            Pool = "Pool0"
            Description = "Application data storage"
            Host_Names = "host1;host2"
            Thin_Provisioned = "Yes"
        },
        [PSCustomObject]@{
            Name = "db_storage_lun_01"
            Size_GB = 2048
            Pool = "Pool0"
            Description = "Database storage"
            Host_Names = "dbhost1"
            Thin_Provisioned = "Yes"
        },
        [PSCustomObject]@{
            Name = "backup_lun_01"
            Size_GB = 5120
            Pool = "Pool1"
            Description = "Backup storage"
            Host_Names = ""
            Thin_Provisioned = "No"
        }
    )
    
    try {
        $sampleData | Export-Csv -Path $FilePath -NoTypeInformation
        Write-Log "Sample CSV created: $FilePath" -Level "SUCCESS"
        Write-Host "Sample CSV file created successfully at: $FilePath" -ForegroundColor Green
    }
    catch {
        Write-Log "Failed to create sample CSV: $($_.Exception.Message)" -Level "ERROR"
    }
}

function New-SampleConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath = "config.json"
    )
    
    $sampleConfig = @{
        PowerStore = @{
            ManagementIP = "192.168.1.100"
            Username = "admin"
            Password = "your_password_here"
            VerifySSL = $false
        }
        Logging = @{
            Level = "INFO"
            LogFile = "PowerStore-Provision.log"
        }
    }
    
    try {
        $sampleConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Log "Sample configuration created: $FilePath" -Level "SUCCESS"
        Write-Host "Sample configuration file created successfully at: $FilePath" -ForegroundColor Green
        Write-Host "Please update the configuration with your PowerStore details before running." -ForegroundColor Yellow
    }
    catch {
        Write-Log "Failed to create sample configuration: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Main Functions

function Start-LUNProvisioning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$CSVPath,
        
        [Parameter(Mandatory = $false)]
        [string]$ReportPath
    )
    
    try {
        # Load configuration
        $Script:PowerStoreConfig = Import-ConfigFile -ConfigPath $ConfigPath
        if (-not $Script:PowerStoreConfig) {
            return
        }
        
        # Connect to PowerStore
        if (-not (Connect-PowerStore -Config $Script:PowerStoreConfig)) {
            return
        }
        
        # Cache existing resources
        Write-Log "Caching PowerStore resources..."
        $hostMap = Get-PowerStoreHosts
        $poolMap = Get-PowerStorePools
        
        # Import LUN requests
        $lunRequests = Import-LUNRequestsFromCSV -CSVPath $CSVPath
        if (-not $lunRequests) {
            return
        }
        
        # Process each LUN request
        $results = @()
        foreach ($lunRequest in $lunRequests) {
            Write-Log "Processing LUN request: $($lunRequest.Name)"
            
            # Validate request
            $validation = Test-LUNRequest -LUNData $lunRequest -PoolMap $poolMap -HostMap $hostMap
            if (-not $validation.IsValid) {
                $result = @{
                    Name = if ($lunRequest.Name) { $lunRequest.Name } else { "Unknown" }
                    Status = "VALIDATION_FAILED"
                    Message = $validation.ErrorMessage
                    LUN_ID = $null
                    WWN = $null
                    Size_GB = if ($lunRequest.Size_GB) { $lunRequest.Size_GB } else { "N/A" }
                    Pool = if ($lunRequest.Pool) { $lunRequest.Pool } else { "N/A" }
                    Hosts_Attached = @()
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $results += $result
                Write-Log "Validation failed for LUN $($lunRequest.Name): $($validation.ErrorMessage)" -Level "ERROR"
                continue
            }
            
            # Create LUN
            $result = New-PowerStoreLUN -LUNData $lunRequest -PoolMap $poolMap -HostMap $hostMap
            $results += $result
            
            # Brief pause between operations
            Start-Sleep -Milliseconds 500
        }
        
        # Generate and export report
        Export-ProvisioningReport -Results $results -OutputPath $ReportPath
        
    }
    catch {
        Write-Log "Critical error during LUN provisioning: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Get-CurrentInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )
    
    try {
        # Load configuration
        $Script:PowerStoreConfig = Import-ConfigFile -ConfigPath $ConfigPath
        if (-not $Script:PowerStoreConfig) {
            return
        }
        
        # Connect to PowerStore
        if (-not (Connect-PowerStore -Config $Script:PowerStoreConfig)) {
            return
        }
        
        # Get inventory
        $inventory = Get-PowerStoreLUNInventory
        
        # Display inventory
        Write-Host "`nCurrent LUN Inventory:" -ForegroundColor Cyan
        Write-Host "=" * 80 -ForegroundColor Cyan
        $inventory | Format-Table -AutoSize
        
        # Export to CSV if path provided
        if ($OutputPath) {
            $inventory | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Log "Inventory exported to: $OutputPath" -Level "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to retrieve inventory: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Main Script Logic

# Initialize logging
Write-Log "PowerStore LUN Provisioning Script started" -Level "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"

# Check PowerShell version
if (-not (Test-PowerShellVersion)) {
    exit 1
}

# Handle parameter combinations
if ($CreateSampleCSV) {
    New-SampleCSV
    exit 0
}

if ($CreateSampleConfig) {
    New-SampleConfig
    exit 0
}

# Validate required parameters
if (-not $InputCSV -and -not $GetInventory) {
    Write-Log "Either -InputCSV or -GetInventory must be specified" -Level "ERROR"
    Write-Host "`nUsage Examples:" -ForegroundColor Yellow
    Write-Host "  .\PowerStore-LUN-Provision.ps1 -ConfigFile 'config.json' -InputCSV 'luns.csv' -OutputReport 'report.csv'" -ForegroundColor Gray
    Write-Host "  .\PowerStore-LUN-Provision.ps1 -ConfigFile 'config.json' -GetInventory" -ForegroundColor Gray
    Write-Host "  .\PowerStore-LUN-Provision.ps1 -CreateSampleCSV" -ForegroundColor Gray
    Write-Host "  .\PowerStore-LUN-Provision.ps1 -CreateSampleConfig" -ForegroundColor Gray
    exit 1
}

# Check if configuration file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level "ERROR"
    Write-Host "Use -CreateSampleConfig to create a sample configuration file." -ForegroundColor Yellow
    exit 1
}

try {
    if ($GetInventory) {
        # Get current inventory
        Get-CurrentInventory -ConfigPath $ConfigFile -OutputPath $OutputReport
    }
    
    if ($InputCSV) {
        # Check if input file exists
        if (-not (Test-Path $InputCSV)) {
            Write-Log "Input CSV file not found: $InputCSV" -Level "ERROR"
            exit 1
        }
        
        # Start LUN provisioning
        Start-LUNProvisioning -ConfigPath $ConfigFile -CSVPath $InputCSV -ReportPath $OutputReport
    }
}
catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-Log "PowerStore LUN Provisioning Script completed" -Level "SUCCESS"

#endregion