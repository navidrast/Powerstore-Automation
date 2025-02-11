# ==========================================================
# Dell.PowerStore File System Creation Script
# ==========================================================
# This script performs the following:
# 1. Checks if the Dell.PowerStore module is installed; if not, installs it.
# 2. Prompts for the PowerStore management IP and admin credentials.
# 3. Connects to the cluster.
# 4. Lists available NAS servers and asks for confirmation to proceed.
# 5. Prompts for a CSV file with file system definitions.
#    Expected CSV columns: FileSystemName, Protocol, NAS_ServerName, CapacityGB, QuotaGB
# 6. Validates each record, converts GB values to bytes, and creates file systems using the REST API.
# 7. Logs successes and failures.
# 8. Generates an HTML report with the cluster name and creation results.
# ==========================================================

# ----- Step 0: Ensure Required Module is Installed -----
Write-Host "Checking if Dell.PowerStore module is installed..."
if (-not (Get-Module -ListAvailable -Name Dell.PowerStore)) {
    Write-Host "Dell.PowerStore module not found. Installing required module..." -ForegroundColor Yellow
    Install-Module -Name Dell.PowerStore -Scope CurrentUser -Force -AllowClobber -Verbose
} else {
    Write-Host "Dell.PowerStore module is already installed." -ForegroundColor Green
}
Import-Module Dell.PowerStore -DisableNameChecking

# ----- Step 1: Connect to the Cluster -----
$clusterIP = Read-Host "Enter the PowerStore Management IP address"
$cred = Get-Credential -Message "Enter your PowerStore admin credentials"
$cluster = Connect-Cluster -HostName $clusterIP -Credential $cred
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

# ----- Step 3: Read CSV File with File System Definitions -----
$csvPath = Read-Host "Enter the full path to the CSV file containing file system definitions"
if (-not (Test-Path $csvPath)) {
    Write-Host "CSV file not found at $csvPath. Exiting." -ForegroundColor Red
    exit
}
$fsRecords = Import-Csv -Path $csvPath
if ($fsRecords.Count -eq 0) {
    Write-Host "CSV file is empty. Exiting." -ForegroundColor Red
    exit
}

# ----- Step 4: Process Each CSV Record and Create File Systems -----
$report = @()  # Array to store results
$total = $fsRecords.Count
$counter = 0

foreach ($record in $fsRecords) {
    $counter++
    Write-Progress -Activity "Processing CSV Records" -Status "Processing record $counter of $total" -PercentComplete (($counter/$total)*100)
    
    $fsName = $record.FileSystemName.Trim()
    $protocol = $record.Protocol.Trim().ToLower()
    $nasServerName = $record.NAS_ServerName.Trim()
    
    # Validate protocol: allow only "smb" or "nfs"
    if ($protocol -ne "smb" -and $protocol -ne "nfs") {
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Failed"
            Message    = "Invalid protocol: $protocol"
        }
        continue
    }
    
    # Match the NAS server based on the CSV NAS_ServerName
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
    
    # Validate and convert CapacityGB to bytes (1 GB = 1073741824 bytes)
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
    
    # Build JSON payload for REST API.
    # Adjust property names if necessary (check your API version)
    $jsonObj = @{
        file_system_name = $fsName
        size             = $sizeBytes
        protocol         = $protocol
    }
    if ($quotaBytes) { $jsonObj.quota = $quotaBytes }
    $jsonPayload = $jsonObj | ConvertTo-Json -Depth 3
    
    # Construct API URL for file system creation
    # Dell documentation: POST /nas_server/{nas_server_id}/fileSystem
    $apiUrl = "https://$clusterIP/api/rest/nas_server/$($nas.id)/fileSystem"
    
    Write-Host "Creating file system '$fsName' on NAS server '$nasServerName' (ID: $($nas.id))..."
    Write-Host "Endpoint: $apiUrl"
    Write-Host "Payload: $jsonPayload"
    
    try {
        # Set TLS and bypass certificate validation if needed
        [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { param($s,$c,$ch,$e) $true }
        
        $result = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonPayload -ContentType "application/json" -Credential $cred -SkipCertificateCheck
        $report += [pscustomobject]@{
            FileSystem = $fsName
            NAS_Server = $nasServerName
            Status     = "Success"
            Message    = "Created successfully"
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

if ($PSScriptRoot) {
    $reportFolder = $PSScriptRoot
} else {
    $reportFolder = Get-Location
}
$reportPath = Join-Path -Path $reportFolder -ChildPath "FileSystemCreationReport.html"
$htmlReport | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "HTML report generated at: $reportPath" -ForegroundColor Green
