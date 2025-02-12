# ==========================================================
# Dell.PowerStore File System Creation/Update Script
# Author: Navid Rastegani, navid.rastegani@optus.com.au
#
# This script:
#   1. Checks for and installs the Dell.PowerStore module if missing.
#   2. Prompts for the PowerStore Management IP and admin credentials (stored for this session),
#      then connects to the cluster (using -IgnoreCertErrors).
#   3. Lists available NAS servers and asks for confirmation.
#   4. Determines the CSV file path:
#         - Checks for "FileSystems.csv" in the script folder.
#         - Otherwise, prompts for the full CSV file path.
#      Expected CSV columns: FileSystemName, NAS_ServerName, Capacity (GiB) / CapacityGB, Quota (GiB) / QuotaGB,
#         Description, ConfigType, AccessPolicy, plus optional extra fields.
#         (There is no Protocol column; the file system uses the NAS server's default protocol.)
#   5. Processes each CSV record:
#         - Validates inputs and converts capacity/quota from GiB to bytes.
#         - Checks if a file system with the same name already exists on the target NAS server.
#             - If it exists, updates settings using Set-FileSystem (including Description, ConfigType,
#               AccessPolicy, and Quota if provided).
#             - Otherwise, creates a new file system using New-FileSystem.
#         - Captures any extra CSV fields for reporting.
#   6. Logs outcomes (Success, Updated, Skipped, Failed) for each record.
#   7. Generates an HTML report with the cluster name and a timestamp in the file name.
# ==========================================================

# ----- Step 0: Ensure Dell.PowerStore Module is Installed -----
Write-Host "Checking if Dell.PowerStore module is installed..."
if (-not (Get-Module -ListAvailable -Name Dell.PowerStore)) {
    Write-Host "Dell.PowerStore module not found. Installing required module..." -ForegroundColor Yellow
    Install-Module -Name Dell.PowerStore -Scope CurrentUser -Force -AllowClobber -Verbose
} else {
    Write-Host "Dell.PowerStore module is already installed." -ForegroundColor Green
}
Import-Module Dell.PowerStore -DisableNameChecking

# ----- Step 1: Connect to the PowerStore Cluster -----
$clusterIP = Read-Host "Enter the PowerStore Management IP address"

# Use a global variable to store credentials for the current session.
if (-not $global:PowerStoreCred) {
    $global:PowerStoreCred = Get-Credential -Message "Enter your PowerStore admin credentials"
    Write-Host "Credentials stored for this session." -ForegroundColor Green
} else {
    Write-Host "Using saved credentials from this session." -ForegroundColor Green
}
$cred = $global:PowerStoreCred

try {
    $cluster = Connect-Cluster -HostName $clusterIP -Credential $cred -IgnoreCertErrors
    Write-Host "Connected to cluster: $($cluster.Name)" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "already connected") {
        Write-Host "Cluster $clusterIP is already connected. Retrieving existing connection..."
        $cluster = Get-Cluster
        Write-Host "Connected to cluster: $($cluster.Name)" -ForegroundColor Green
    } else {
        throw $_
    }
}

# ----- Step 2: List NAS Servers and Confirm -----
$nasList = Get-NasServer -Cluster $cluster
if (-not $nasList) {
    Write-Host "No NAS servers found on the cluster. Exiting." -ForegroundColor Red
    exit
}
Write-Host "Available NAS Servers:" -ForegroundColor Cyan
$nasList | Format-Table id, name, NAS_IP
$confirm = Read-Host "Do you want to proceed with file system creation/update? (Y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "User cancelled. Exiting." -ForegroundColor Yellow
    exit
}

# ----- Step 3: Determine CSV File Path -----
if ($PSScriptRoot) {
    $defaultCsvPath = Join-Path -Path $PSScriptRoot -ChildPath "FileSystems.csv"
} else {
    $defaultCsvPath = "FileSystems.csv"
}
if (Test-Path $defaultCsvPath) {
    Write-Host "Using CSV file found in script folder: $defaultCsvPath" -ForegroundColor Green
    $csvPath = $defaultCsvPath
} else {
    $csvPath = Read-Host "CSV file 'FileSystems.csv' not found in the script folder. Enter the full path to the CSV file"
}
if (-not (Test-Path $csvPath)) {
    Write-Host "CSV file not found at $csvPath. Exiting." -ForegroundColor Red
    exit
}
$fsRecords = Import-Csv -Path $csvPath
if ($fsRecords.Count -eq 0) {
    Write-Host "CSV file is empty. Exiting." -ForegroundColor Red
    exit
}

# ----- Step 4: Process CSV Records and Create/Update File Systems -----
$report = @()  # Array to store results
$total = $fsRecords.Count
$counter = 0

# Define extra CSV headers for reporting purposes.
$extraHeaders = @("Allocated (GiB)","Protocol","Restricted Replication Access","Snapshots",
                  "Snapshot Space Used (GiB)","Snapshot Schedule","Thin","Tiering Policy",
                  "Used (GiB)","Synchronous","Asynchronous","Data Reduction",
                  "Data Reduction Savings (GiB)","Advanced Deduplication")

foreach ($record in $fsRecords) {
    $counter++
    Write-Progress -Activity "Processing CSV Records" -Status "Record $counter of $total" -PercentComplete (($counter/$total)*100)
    
    $fsName = $record.FileSystemName.Trim()
    $nasServerName = $record.NAS_ServerName.Trim()
    
    # Match the NAS server (exact match)
    $nas = $nasList | Where-Object { $_.Name -eq $nasServerName }
    if (-not $nas) {
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Failed"
            Message    = "NAS server '$nasServerName' not found"
            Extra      = ""
        }
        continue
    }
    
    # Check if file system with the same name exists on this NAS server.
    $existingFS = Get-FileSystem -Cluster $cluster | Where-Object { $_.Name -eq $fsName -and $_.NasServerId -eq $nas.id }
    if ($existingFS) {
        Write-Host "File system '$fsName' already exists on NAS server '$nasServerName'. Updating settings..."
        try {
            # Build update parameter list (update optional fields: Description, ConfigType, AccessPolicy, Quota)
            $updateParams = @{
                Cluster      = $cluster
                FileSystemId = $existingFS.Id
            }
            if ($record.Description) { $updateParams.Description = $record.Description.Trim() }
            if ($record.ConfigType) { $updateParams.ConfigType = $record.ConfigType.Trim() }
            if ($record.AccessPolicy) { $updateParams.AccessPolicy = $record.AccessPolicy.Trim() }
            if ($record.QuotaGB -or $record."Quota (GiB)") {
                $qVal = $record."Quota (GiB)"
                if (-not $qVal) { $qVal = $record.QuotaGB }
                if ([double]::TryParse($qVal, [ref]$null)) {
                    $quotaGB = [double]$qVal
                    $updateParams.Quota = [math]::Round($quotaGB * 1073741824)
                }
            }
            Set-FileSystem @updateParams
            $action = "Updated"
            $msg = "File system updated successfully"
        } catch {
            $action = "Update Failed"
            $msg = $_.Exception.Message
        }
        # Capture extra CSV fields for reporting.
        $extraSettings = @{}
        foreach ($header in $extraHeaders) {
            if ($record.PSObject.Properties.Name -contains $header) {
                $extraSettings[$header] = $record.$header
            }
        }
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = $action
            Message    = $msg
            Extra      = (ConvertTo-Json $extraSettings -Depth 3)
        }
        continue
    }
    
    # Validate and convert Capacity to bytes (using "Capacity (GiB)" or CapacityGB)
    $capacityVal = $record."Capacity (GiB)"
    if (-not $capacityVal) { $capacityVal = $record.CapacityGB }
    if (-not [double]::TryParse($capacityVal, [ref]$null)) {
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Failed"
            Message    = "Invalid capacity value: $capacityVal"
            Extra      = ""
        }
        continue
    }
    $capacityGB = [double]$capacityVal
    $sizeBytes = [math]::Round($capacityGB * 1073741824)
    
    # Process Quota (using "Quota (GiB)" or QuotaGB)
    $quotaVal = $record."Quota (GiB)"
    if (-not $quotaVal) { $quotaVal = $record.QuotaGB }
    $quotaBytes = $null
    if ($quotaVal -and [double]::TryParse($quotaVal, [ref]$null)) {
        $quotaGB = [double]$quotaVal
        $quotaBytes = [math]::Round($quotaGB * 1073741824)
    }
    
    # Optional parameters (Description, ConfigType, AccessPolicy)
    $description = $null
    if ($record.Description) { $description = $record.Description.Trim() }
    $configType = $null
    if ($record.ConfigType) { $configType = $record.ConfigType.Trim() }
    $accessPolicy = $null
    if ($record.AccessPolicy) { $accessPolicy = $record.AccessPolicy.Trim() }
    
    Write-Host "Creating file system '$fsName' on NAS server '$nasServerName'..."
    try {
        $params = @{
            Cluster   = $cluster
            NasServer = $nasServerName
            Name      = $fsName
            Size      = $sizeBytes
        }
        if ($description) { $params.Description = $description }
        if ($configType) { $params.ConfigType = $configType }
        if ($accessPolicy) { $params.AccessPolicy = $accessPolicy }
        $fsResult = New-FileSystem @params
        $action = "Success"
        $msg = "File system created (ID: $($fsResult.Id))"
    }
    catch {
        $action = "Failed"
        $msg = $_.Exception.Message
    }
    
    $extraSettings = @{}
    foreach ($header in $extraHeaders) {
        if ($record.PSObject.Properties.Name -contains $header) {
            $extraSettings[$header] = $record.$header
        }
    }
    $report += [pscustomobject]@{
        FileSystem = $fsName
        NAS_Server = $nasServerName
        Status     = $action
        Message    = $msg
        Extra      = (ConvertTo-Json $extraSettings -Depth 3)
    }
}

# ----- Step 5: Generate HTML Report -----
$head = "<style>table, th, td { border: 1px solid black; border-collapse: collapse; padding: 5px; }</style>"
$preContent = "<h1>Cluster: $($cluster.Name)</h1><p>Date: $(Get-Date)</p>"
$htmlReport = $report | ConvertTo-Html -Head $head -Title "File System Creation Report for $($cluster.Name)" -PreContent $preContent

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$reportFileName = "$($cluster.Name)_$timestamp.html"
if ($PSScriptRoot) {
    $reportFolder = $PSScriptRoot
} else {
    $reportFolder = Get-Location
}
$reportPath = Join-Path -Path $reportFolder -ChildPath $reportFileName
$htmlReport | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "HTML report generated at: $reportPath" -ForegroundColor Green
