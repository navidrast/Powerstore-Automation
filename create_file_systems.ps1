# Prompt for PowerStore connection details
$powerstoreIP = Read-Host "Enter PowerStore IP address"
$username = Read-Host "Enter username"
$password = Read-Host "Enter password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

# Prompt for NAS details (these will be used for all file system creations)
$nasIP = Read-Host "Enter NAS IP address"

# Define the CSV file path (ensure it exists in the current folder)
$csvFile = "file_systems.csv"
if (-Not (Test-Path $csvFile)) {
    Write-Host "Error: CSV file '$csvFile' not found."
    exit
}

# Import CSV file and force it into an array (handles single-record cases)
$fileSystems = @(Import-Csv -Path $csvFile)

# Get the total number of records
$total = $fileSystems.Count
if ($total -eq 0) {
    Write-Host "CSV file is empty. Please populate it with at least one record."
    exit
}

Write-Host "Starting creation of $total filesystems..."

# Set security protocol to TLS 1.2 (if required by the PowerStore API)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$counter = 0
foreach ($fs in $fileSystems) {
    $counter++
    $fsName = $fs.FileSystemName

    # Ensure the Protocol field is trimmed and in lowercase
    $protocol = ($fs.Protocol).Trim().ToLower()

    if ($protocol -eq "nfs" -or $protocol -eq "smb") {

        # Calculate progress percentage
        $percentComplete = ($counter / $total) * 100
        Write-Progress -Activity "Creating File Systems" `
                       -Status "Processing '$fsName'" `
                       -PercentComplete $percentComplete

        Write-Host "[$counter/$total] Pending: Creating filesystem '$fsName' with protocol '$protocol'..."

        try {
            # Construct the API endpoint URL (adjust if needed)
            $url = "https://$powerstoreIP/api/v1/filesystems/"

            # Build the request body as a hashtable using the prompted NAS IP.
            $body = @{
                NAS_Name       = $fs.NAS_Name    # This is a label from the CSV (optional)
                NAS_IP         = $nasIP          # Use NAS IP from prompt
                FileSystemName = $fs.FileSystemName
                Size           = [long]$fs.Size
                Protocol       = $protocol       # Use protocol from CSV (nfs or smb)
            }

            # Include Quota if provided in CSV
            if ($fs.Quota -and $fs.Quota.Trim() -ne "") {
                $body.Quota = [long]$fs.Quota
            }

            # Convert the hashtable to JSON
            $jsonBody = $body | ConvertTo-Json

            # Debug output to check URL and payload
            Write-Host "API URL: $url"
            Write-Host "JSON Body: $jsonBody"

            # Bypass certificate validation (for self-signed certificates)
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

            # Invoke REST API
            $response = Invoke-RestMethod -Uri $url -Method Post -Body $jsonBody `
                        -ContentType "application/json" -Credential $cred
            Write-Host "[$counter/$total] Completed: Filesystem '$fsName' created. Response: $( $response | ConvertTo-Json -Depth 3 )"
        }
        catch {
            Write-Host "[$counter/$total] Error: Could not create filesystem '$fsName'. $_"
        }
    }
    else {
        Write-Host "[$counter/$total] No valid filesystem protocol requested for '$fsName'."
    }
}
