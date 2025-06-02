#Requires -Version 5.1
<#
.SYNOPSIS
    PowerStore Advanced Report Generator
    
.DESCRIPTION
    This script generates comprehensive reports from PowerStore arrays in the same format
    as your existing CSV exports. It can be used for capacity planning, compliance reporting,
    and infrastructure documentation.
    
.PARAMETER ConfigFile
    Path to configuration file containing PowerStore connection details
    
.PARAMETER OutputDirectory
    Directory to save report files (default: reports)
    
.PARAMETER AllReports
    Generate all report types
    
.PARAMETER LUNsOnly
    Generate LUNs report only
    
.PARAMETER HostsOnly
    Generate hosts report only
    
.PARAMETER PoolsOnly
    Generate storage pools report only
    
.PARAMETER FileSystemsOnly
    Generate file systems report only
    
.PARAMETER NFSOnly
    Generate NFS shares report only
    
.EXAMPLE
    .\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -AllReports
    
.EXAMPLE
    .\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -LUNsOnly -OutputDirectory "reports"
    
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
    [string]$OutputDirectory = "reports",
    
    [Parameter(Mandatory = $false)]
    [switch]$AllReports,
    
    [Parameter(Mandatory = $false)]
    [switch]$LUNsOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$HostsOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$PoolsOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$FileSystemsOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$NFSOnly
)

# Global variables
$Script:LogFile = "PowerStore-Reports-$(Get-Date -Format 'yyyy-MM-dd').log"
$Script:PowerStoreConfig = $null
$Script:AuthHeaders = $null
$Script:BaseUri = $null
$Script:ArrayName = "PowerStore"

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

function New-LUNReport {
    try {
        Write-Log "Generating LUN report..."
        
        # Get all volumes
        $volumes = Invoke-PowerStoreAPI -Endpoint "volume"
        
        $lunData = @()
        foreach ($volume in $volumes) {
            try {
                # Get volume details
                $volumeDetails = Invoke-PowerStoreAPI -Endpoint "volume/$($volume.id)"
                
                # Get host mappings count
                $hostCount = 0
                try {
                    $mappings = Invoke-PowerStoreAPI -Endpoint "volume_host_mapping" -QueryParameters @{ volume_id = $volume.id }
                    $hostCount = if ($mappings) { $mappings.Count } else { 0 }
                }
                catch {
                    # Host mappings might not exist
                    $hostCount = 0
                }
                
                # Get storage pool name
                $poolName = "Unknown"
                if ($volumeDetails.storage_pool -and $volumeDetails.storage_pool.name) {
                    $poolName = $volumeDetails.storage_pool.name
                }
                
                $lunItem = [PSCustomObject]@{
                    "!" = "OK"
                    "Name" = $volume.name
                    "Size (GB)" = "{0:N1}" -f ($volume.size / 1GB)
                    "Allocated (%)" = if ($volumeDetails.allocated_percent) { $volumeDetails.allocated_percent } else { 0 }
                    "Pool" = $poolName
                    "Type" = "LUN"
                    "Description" = if ($volume.description) { $volume.description } else { "" }
                    "Hosts" = $hostCount
                    "Replication Type" = if ($volumeDetails.replication_role) { $volumeDetails.replication_role } else { "None" }
                    "Thin" = if ($volumeDetails.is_thin_enabled) { "Yes" } else { "No" }
                    "WWN" = if ($volumeDetails.wwn) { $volumeDetails.wwn } else { "" }
                    "Thin Clone Base" = "--"
                }
                
                $lunData += $lunItem
            }
            catch {
                Write-Log "Failed to get details for volume $($volume.name): $($_.Exception.Message)" -Level "WARNING"
                
                $lunItem = [PSCustomObject]@{
                    "!" = "Warning"
                    "Name" = $volume.name
                    "Size (GB)" = "{0:N1}" -f ($volume.size / 1GB)
                    "Type" = "LUN"
                    "Status" = "Incomplete data"
                }
                
                $lunData += $lunItem
            }
        }
        
        Write-Log "Generated report for $($lunData.Count) LUNs" -Level "SUCCESS"
        return $lunData
    }
    catch {
        Write-Log "Failed to generate LUN report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function New-HostReport {
    try {
        Write-Log "Generating host report..."
        
        # Get all hosts
        $hosts = Invoke-PowerStoreAPI -Endpoint "host"
        
        $hostData = @()
        foreach ($host in $hosts) {
            try {
                # Get host details
                $hostDetails = Invoke-PowerStoreAPI -Endpoint "host/$($host.id)"
                
                # Get network addresses from initiators
                $networkAddresses = @()
                if ($hostDetails.host_initiators) {
                    foreach ($initiator in $hostDetails.host_initiators) {
                        if ($initiator.port_name) {
                            $networkAddresses += $initiator.port_name
                        }
                    }
                }
                
                # Get LUN mappings count
                $lunCount = 0
                try {
                    $mappings = Invoke-PowerStoreAPI -Endpoint "volume_host_mapping" -QueryParameters @{ host_id = $host.id }
                    $lunCount = if ($mappings) { $mappings.Count } else { 0 }
                }
                catch {
                    $lunCount = 0
                }
                
                # Calculate initiator paths
                $initiatorPaths = 0
                if ($hostDetails.host_initiators) {
                    foreach ($initiator in $hostDetails.host_initiators) {
                        if ($initiator.paths) {
                            $initiatorPaths += $initiator.paths.Count
                        }
                    }
                }
                
                $hostItem = [PSCustomObject]@{
                    "!" = "OK"
                    "Name" = $host.name
                    "Network Addresses" = if ($networkAddresses.Count -gt 0) { ($networkAddresses[0..2] -join ";") } else { $host.name }
                    "Operating System" = if ($hostDetails.os_type) { $hostDetails.os_type } else { "" }
                    "Type" = if ($hostDetails.host_group_id) { "Group Member" } else { "Manual" }
                    "LUNs" = $lunCount
                    "Initiators" = if ($hostDetails.host_initiators) { $hostDetails.host_initiators.Count } else { 0 }
                    "Initiator Paths" = $initiatorPaths
                    "CLI ID" = "Host_$($host.id)"
                }
                
                $hostData += $hostItem
            }
            catch {
                Write-Log "Failed to get details for host $($host.name): $($_.Exception.Message)" -Level "WARNING"
                
                $hostItem = [PSCustomObject]@{
                    "!" = "Warning"
                    "Name" = $host.name
                    "Status" = "Incomplete data"
                }
                
                $hostData += $hostItem
            }
        }
        
        Write-Log "Generated report for $($hostData.Count) hosts" -Level "SUCCESS"
        return $hostData
    }
    catch {
        Write-Log "Failed to generate host report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function New-StoragePoolReport {
    try {
        Write-Log "Generating storage pool report..."
        
        # Get all storage pools
        $pools = Invoke-PowerStoreAPI -Endpoint "storage_pool"
        
        $poolData = @()
        foreach ($pool in $pools) {
            try {
                # Get pool details
                $poolDetails = Invoke-PowerStoreAPI -Endpoint "storage_pool/$($pool.id)"
                
                # Calculate metrics
                $sizeTB = [math]::Round($pool.size / 1TB, 1)
                $usedTB = [math]::Round(($pool.size - $pool.free_size) / 1TB, 1)
                $freeTB = [math]::Round($pool.free_size / 1TB, 1)
                $usedPercent = [math]::Round((($pool.size - $pool.free_size) / $pool.size) * 100, 1)
                
                # Get subscription percentage
                $subscriptionPercent = if ($poolDetails.subscription_percent) { [math]::Round($poolDetails.subscription_percent, 1) } else { 0 }
                
                # Determine status
                $status = if ($usedPercent -lt 90) { "OK" } else { "OK, Needs Attention" }
                
                $poolItem = [PSCustomObject]@{
                    "!" = $status
                    "Name" = $pool.name
                    "Size (TB)" = $sizeTB
                    "Free (TB)" = $freeTB
                    "Preallocated (GB)" = if ($poolDetails.preallocated_size) { [math]::Round($poolDetails.preallocated_size / 1GB, 1) } else { 0 }
                    "Used (%)" = $usedPercent
                    "Subscription (%)" = $subscriptionPercent
                    "Used (TB)" = "`"$usedTB`"`""
                }
                
                $poolData += $poolItem
            }
            catch {
                Write-Log "Failed to get details for pool $($pool.name): $($_.Exception.Message)" -Level "WARNING"
                
                $poolItem = [PSCustomObject]@{
                    "!" = "Warning"
                    "Name" = $pool.name
                    "Status" = "Incomplete data"
                }
                
                $poolData += $poolItem
            }
        }
        
        Write-Log "Generated report for $($poolData.Count) storage pools" -Level "SUCCESS"
        return $poolData
    }
    catch {
        Write-Log "Failed to generate storage pool report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function New-FileSystemReport {
    try {
        Write-Log "Generating file system report..."
        
        # Get NAS servers first
        $nasServers = @{}
        try {
            $nasServerList = Invoke-PowerStoreAPI -Endpoint "nas_server"
            foreach ($nas in $nasServerList) {
                $nasServers[$nas.id] = $nas.name
            }
        }
        catch {
            Write-Log "Could not retrieve NAS servers, file system report may be incomplete" -Level "WARNING"
        }
        
        # Get file systems
        $fileSystems = Invoke-PowerStoreAPI -Endpoint "file_system"
        
        $fsData = @()
        foreach ($fs in $fileSystems) {
            try {
                # Get file system details
                $fsDetails = Invoke-PowerStoreAPI -Endpoint "file_system/$($fs.id)"
                
                # Get shares count
                $sharesCount = 0
                try {
                    $shares = Invoke-PowerStoreAPI -Endpoint "nfs_export" -QueryParameters @{ file_system_id = $fs.id }
                    $sharesCount = if ($shares) { $shares.Count } else { 0 }
                }
                catch {
                    $sharesCount = 0
                }
                
                # Calculate usage metrics
                $capacityGB = [math]::Round($fs.size_total / 1GB, 2)
                $usedGB = [math]::Round($fs.size_used / 1GB, 2)
                $freeGB = [math]::Round(($fs.size_total - $fs.size_used) / 1GB, 2)
                $usagePercent = if ($fs.size_total -gt 0) { [math]::Round(($fs.size_used / $fs.size_total) * 100, 1) } else { 0 }
                
                $fsItem = [PSCustomObject]@{
                    "System Name" = $Script:ArrayName
                    "File System" = $fs.name
                    "Protocol Type" = if ($fsDetails.protocol) { $fsDetails.protocol } else { "NFS" }
                    "Type" = "Primary"
                    "NAS Server" = if ($nasServers[$fs.nas_server_id]) { $nasServers[$fs.nas_server_id] } else { "Unknown" }
                    "Storage Pool" = if ($fsDetails.storage_pool -and $fsDetails.storage_pool.name) { $fsDetails.storage_pool.name } else { "Unknown" }
                    "# Shares" = $sharesCount
                    "# Quotas" = 0
                    "Capacity (GB)" = $capacityGB
                    "Used Capacity (GB)" = $usedGB
                    "Free Capacity (GB)" = $freeGB
                    "Presented Capacity (GB)" = $capacityGB
                    "Logical Used Capacity (GB)" = $usedGB
                    "Data Reduction?" = if ($fsDetails.data_reduction_enabled) { 1 } else { 0 }
                    "Data Reduction Savings" = if ($fsDetails.data_reduction_ratio) { "$($fsDetails.data_reduction_ratio):1" } else { "1.0:1" }
                    "Usage (%)" = $usagePercent
                    "Bandwidth (MB/s)" = 0
                    "Throughput (IOPS)" = 0
                    "Status" = "OK"
                }
                
                $fsData += $fsItem
            }
            catch {
                Write-Log "Failed to get details for file system $($fs.name): $($_.Exception.Message)" -Level "WARNING"
                
                $fsItem = [PSCustomObject]@{
                    "System Name" = $Script:ArrayName
                    "File System" = $fs.name
                    "Status" = "Incomplete data"
                }
                
                $fsData += $fsItem
            }
        }
        
        Write-Log "Generated report for $($fsData.Count) file systems" -Level "SUCCESS"
        return $fsData
    }
    catch {
        Write-Log "Failed to generate file system report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function New-NFSShareReport {
    try {
        Write-Log "Generating NFS share report..."
        
        # Get NAS servers
        $nasServers = @{}
        try {
            $nasServerList = Invoke-PowerStoreAPI -Endpoint "nas_server"
            foreach ($nas in $nasServerList) {
                $nasServers[$nas.id] = $nas.name
            }
        }
        catch {
            Write-Log "Could not retrieve NAS servers" -Level "WARNING"
        }
        
        # Get file systems
        $fileSystems = @{}
        try {
            $fslist = Invoke-PowerStoreAPI -Endpoint "file_system"
            foreach ($fs in $fslist) {
                $fileSystems[$fs.id] = $fs.name
            }
        }
        catch {
            Write-Log "Could not retrieve file systems" -Level "WARNING"
        }
        
        # Get NFS exports
        $nfsExports = Invoke-PowerStoreAPI -Endpoint "nfs_export"
        
        $shareData = @()
        foreach ($export in $nfsExports) {
            try {
                # Get export details
                $exportDetails = Invoke-PowerStoreAPI -Endpoint "nfs_export/$($export.id)"
                
                # Count hosts/clients
                $hostCount = 0
                if ($exportDetails.read_only_hosts) {
                    $hostCount += $exportDetails.read_only_hosts.Count
                }
                if ($exportDetails.read_write_hosts) {
                    $hostCount += $exportDetails.read_write_hosts.Count
                }
                
                $shareItem = [PSCustomObject]@{
                    "Share Name" = $export.name
                    "Type" = "NFS"
                    "NAS Server" = if ($nasServers[$export.nas_server_id]) { $nasServers[$export.nas_server_id] } else { "Unknown" }
                    "File System" = if ($fileSystems[$export.file_system_id]) { $fileSystems[$export.file_system_id] } else { "Unknown" }
                    "Local Path" = $export.path
                    "CLI ID" = $export.id
                    "Export Paths" = $export.path
                    "Hosts" = $hostCount
                }
                
                $shareData += $shareItem
            }
            catch {
                Write-Log "Failed to get details for NFS export $($export.name): $($_.Exception.Message)" -Level "WARNING"
                
                $shareItem = [PSCustomObject]@{
                    "Share Name" = $export.name
                    "Type" = "NFS"
                    "Status" = "Incomplete data"
                }
                
                $shareData += $shareItem
            }
        }
        
        Write-Log "Generated report for $($shareData.Count) NFS shares" -Level "SUCCESS"
        return $shareData
    }
    catch {
        Write-Log "Failed to generate NFS share report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Export-Reports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Reports,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )
    
    try {
        # Create output directory if it doesn't exist
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"
        $arrayPrefix = $Script:ArrayName -replace '\s', ''
        $generatedFiles = @()
        
        foreach ($reportType in $Reports.Keys) {
            try {
                Write-Log "Generating $reportType report..."
                $reportData = & $Reports[$reportType]
                
                $filename = "$($arrayPrefix)_$($reportType)_TableExportData_$timestamp.csv"
                $filepath = Join-Path $OutputDir $filename
                
                $reportData | Export-Csv -Path $filepath -NoTypeInformation
                $generatedFiles += $filepath
                
                Write-Log "Saved $reportType report: $filepath" -Level "SUCCESS"
            }
            catch {
                Write-Log "Failed to generate $reportType report: $($_.Exception.Message)" -Level "ERROR"
            }
        }
        
        # Generate summary report
        $summaryData = @()
        foreach ($reportType in $Reports.Keys) {
            $status = if ($generatedFiles | Where-Object { $_ -like "*$reportType*" }) { "Generated" } else { "Failed" }
            
            $summaryItem = [PSCustomObject]@{
                "Report Type" = $reportType
                "Status" = $status
                "Timestamp" = $timestamp
                "Array" = $Script:ArrayName
            }
            $summaryData += $summaryItem
        }
        
        $summaryFile = Join-Path $OutputDir "$($arrayPrefix)_ReportSummary_$timestamp.csv"
        $summaryData | Export-Csv -Path $summaryFile -NoTypeInformation
        
        # Display results
        Write-Host "`nReport Generation Complete" -ForegroundColor Cyan
        Write-Host "Output directory: $(Resolve-Path $OutputDir)" -ForegroundColor Cyan
        Write-Host "Generated files:" -ForegroundColor White
        
        foreach ($file in $generatedFiles) {
            Write-Host "  - $(Split-Path $file -Leaf)" -ForegroundColor Green
        }
        Write-Host "  - $(Split-Path $summaryFile -Leaf)" -ForegroundColor Green
        
        return $generatedFiles
    }
    catch {
        Write-Log "Failed to export reports: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Main Functions

function Start-ReportGeneration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ReportsToGenerate
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
        
        # Generate and export reports
        Export-Reports -Reports $ReportsToGenerate -OutputDir $OutputDir
    }
    catch {
        Write-Log "Critical error during report generation: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Main Script Logic

# Initialize logging
Write-Log "PowerStore Report Generator started" -Level "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Log "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level "ERROR"
    exit 1
}

# Check if configuration file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level "ERROR"
    Write-Host "Please ensure the configuration file exists." -ForegroundColor Yellow
    exit 1
}

# Validate that at least one report type is specified
if (-not ($AllReports -or $LUNsOnly -or $HostsOnly -or $PoolsOnly -or $FileSystemsOnly -or $NFSOnly)) {
    Write-Log "Please specify a report type" -Level "ERROR"
    Write-Host "`nUsage Examples:" -ForegroundColor Yellow
    Write-Host "  .\PowerStore-Report-Generator.ps1 -ConfigFile 'config.json' -AllReports" -ForegroundColor Gray
    Write-Host "  .\PowerStore-Report-Generator.ps1 -ConfigFile 'config.json' -LUNsOnly" -ForegroundColor Gray
    Write-Host "  .\PowerStore-Report-Generator.ps1 -ConfigFile 'config.json' -HostsOnly -OutputDirectory 'reports'" -ForegroundColor Gray
    exit 1
}

try {
    # Define available reports
    $availableReports = @{
        "LUNs" = { New-LUNReport }
        "Hosts" = { New-HostReport }
        "StoragePools" = { New-StoragePoolReport }
        "FileSystems" = { New-FileSystemReport }
        "NFSShares" = { New-NFSShareReport }
    }
    
    # Determine which reports to generate
    $reportsToGenerate = @{}
    
    if ($AllReports) {
        $reportsToGenerate = $availableReports
    }
    else {
        if ($LUNsOnly) { $reportsToGenerate["LUNs"] = $availableReports["LUNs"] }
        if ($HostsOnly) { $reportsToGenerate["Hosts"] = $availableReports["Hosts"] }
        if ($PoolsOnly) { $reportsToGenerate["StoragePools"] = $availableReports["StoragePools"] }
        if ($FileSystemsOnly) { $reportsToGenerate["FileSystems"] = $availableReports["FileSystems"] }
        if ($NFSOnly) { $reportsToGenerate["NFSShares"] = $availableReports["NFSShares"] }
    }
    
    # Start report generation
    Start-ReportGeneration -ConfigPath $ConfigFile -OutputDir $OutputDirectory -ReportsToGenerate $reportsToGenerate
}
catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-Log "PowerStore Report Generator completed" -Level "SUCCESS"

#endregion