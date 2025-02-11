# ==========================================================
# Dell.PowerStore File System Creation Script
# Author: Navid Rastegani, navid.rastegani@optus.com.au
#
# This script performs the following:
#   1. Checks for and installs the Dell.PowerStore module if missing.
#   2. Prompts for the PowerStore Management IP and admin credentials,
#      then connects to the cluster (with -IgnoreCertErrors to bypass cert issues).
#   3. Lists available NAS servers and asks for user confirmation.
#   4. Determines the CSV file path:
#         - First, checks if "FileSystems.csv" exists in the script folder.
#         - Otherwise, prompts for the full CSV file path.
#      Expected CSV columns: FileSystemName, NAS_ServerName, CapacityGB, QuotaGB, [Description, ConfigType, AccessPolicy]
#      (Note: There is no Protocol column; the file system will follow the protocol defined on the NAS server.)
#   5. Processes each CSV record:
#         - Validates that CapacityGB is numeric and converts it to bytes.
#         - Processes QuotaGB if provided.
#         - Creates a file system using New-FileSystem.
#   6. Logs successes and failures.
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
$cred = Get-Credential -Message "Enter your PowerStore admin credentials"
# Use -IgnoreCertErrors to bypass certificate errors if needed
$cluster = Connect-Cluster -HostName $clusterIP -Credential $cred -IgnoreCertErrors
Write-Host "Connected to cluster: $($cluster.Name)" -ForegroundColor Green

# ----- Step 2: List NAS Servers and Confirm -----
$nasList = Get-NasServer -Cluster $cluster
if (-not $nasList) {
    Write-Host "No NAS servers found on the cluster. Exiting." -ForegroundColor Red
    exit
}
Write-Host "Available NAS Servers:" -ForegroundColor Cyan
$nasList | Format-Table id, name, NAS_IP
$confirm = Read-Host "Do you want to proceed with file system creation? (Y/N)"
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

# ----- Step 4: Process CSV Records and Create File Systems -----
$report = @()  # Array to store results
$total = $fsRecords.Count
$counter = 0

foreach ($record in $fsRecords) {
    $counter++
    Write-Progress -Activity "Processing CSV Records" -Status "Record $counter of $total" -PercentComplete (($counter/$total)*100)
    
    $fsName = $record.FileSystemName.Trim()
    $nasServerName = $record.NAS_ServerName.Trim()
    
    # Match the NAS server based on the CSV NAS_ServerName (exact match)
    $nas = $nasList | Where-Object { $_.Name -eq $nasServerName }
    if (-not $nas) {
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Failed"
            Message    = "NAS server '$nasServerName' not found"
        }
        continue
    }
    
    # Validate and convert CapacityGB to bytes (1GB = 1073741824 bytes)
    if (-not [double]::TryParse($record.CapacityGB, [ref]$null)) {
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Failed"
            Message    = "Invalid CapacityGB: $($record.CapacityGB)"
        }
        continue
    }
    $capacityGB = [double]$record.CapacityGB
    $sizeBytes = [math]::Round($capacityGB * 1073741824)
    
    # Process QuotaGB if provided (optional)
    $quotaBytes = $null
    if ($record.QuotaGB -and [double]::TryParse($record.QuotaGB, [ref]$null)) {
        $quotaGB = [double]$record.QuotaGB
        $quotaBytes = [math]::Round($quotaGB * 1073741824)
    }
    
    # Optional parameters from CSV (Description, ConfigType, AccessPolicy)
    $description = $null
    if ($record.Description) { $description = $record.Description.Trim() }
    $configType = $null
    if ($record.ConfigType) { $configType = $record.ConfigType.Trim() }
    $accessPolicy = $null
    if ($record.AccessPolicy) { $accessPolicy = $record.AccessPolicy.Trim() }
    
    Write-Host "Creating file system '$fsName' on NAS server '$nasServerName'..."
    try {
        # Build the parameter list for New-FileSystem
        $params = @{
            Cluster   = $cluster
            NasServer = $nasServerName
            Name      = $fsName
            Size      = $sizeBytes
        }
        if ($description) { $params.Description = $description }
        if ($configType) { $params.ConfigType = $configType }
        if ($accessPolicy) { $params.AccessPolicy = $accessPolicy }
        
        # Create the file system using the module cmdlet
        $fsResult = New-FileSystem @params
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Success"
            Message    = "File system created (ID: $($fsResult.Id))"
        }
    }
    catch {
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Failed"
            Message    = $_.Exception.Message
        }
    }
}

# ----- Step 5: Generate HTML Report -----
$head = "<style>table, th, td { border: 1px solid black; border-collapse: collapse; padding: 5px; }</style>"
$preContent = "<h1>Cluster: $($cluster.Name)</h1><p>Date: $(Get-Date)</p>"
$htmlReport = $report | ConvertTo-Html -Head $head -Title "File System Creation Report for $($cluster.Name)" -PreContent $preContent

# Create a timestamp for the report file name (format: yyyyMMdd_HHmmss)
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
