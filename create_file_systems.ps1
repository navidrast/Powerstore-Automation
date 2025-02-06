# Prompt for PowerStore connection details
$powerstoreIP = Read-Host "Enter PowerStore IP address"
$username = Read-Host "Enter username"
$password = Read-Host "Enter password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

# Prompt for NAS details (these will be used for all file system creations)
$nasIP = Read-Host "Enter NAS IP address"
$nasProtocol = Read-Host "Enter protocol (nfs/smb)"

# Define the CSV file path (make sure it exists in the current folder)
$csvFile = "file_systems.csv"
if (-Not (Test-Path $csvFile)) {
    Write-Host "Error: CSV file '$csvFile' not found."
    exit
}

# Import CSV file
$fileSystems = Import-Csv -Path $csvFile

# Check if CSV file has any records
$total = $fileSystems.Count
if ($total -eq 0) {
    Write-Host "CSV file is empty. Please populate it with at least one record."
    exit
}

Write-Host "Starting creation of $total filesystems..."

$counter = 0
foreach ($fs in $fileSystems) {
    $counter++
    $fsName = $fs.FileSystemName

    # Calculate progress percentage (avoid division by zero since we checked above)
    $percentComplete = ($counter / $total) * 100
    Write-Progress -Activity "Creating File Systems" `
                   -Status "Processing '$fsName'" `
                   -PercentComplete $percentComplete

    Write-Host "[$counter/$total] Pending: Creating filesystem '$fsName'..."

    try {
        # Construct the API endpoint URL (adjust if needed—some environments require a trailing slash)
        $url = "https://$powerstoreIP/api/v1/filesystems/"

        # Build the request body as a hashtable using the prompted NAS details.
        # Note: If the API expects a different payload structure, adjust the keys accordingly.
        $body = @{
            # You can omit NAS_Name if the API does not expect it,
            # or use a static value if required.
            NAS_Name       = $fs.NAS_Name  
            NAS_IP         = $nasIP          # Use NAS IP from prompt
            FileSystemName = $fs.FileSystemName
            Size           = [long]$fs.Size
            Protocol       = $nasProtocol    # Use protocol from prompt
        }

        # Include Quota if provided in CSV
        if ($fs.Quota -and $fs.Quota.Trim() -ne "") {
            $body.Quota = [long]$fs.Quota
        }

        # Convert the hashtable to JSON
        $jsonBody = $body | ConvertTo-Json

        # Debugging: Show the API URL and JSON payload before calling the API
        Write-Host "API URL: $url"
        Write-Host "JSON Body: $jsonBody"

        # Bypass certificate validation (for self-signed certificates)
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

        # Invoke REST API (note: -SkipCertificateCheck is removed for PowerShell 5.1)
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $jsonBody `
                    -ContentType "application/json" -Credential $cred
        Write-Host "[$counter/$total] Completed: Filesystem '$fsName' created. Response: $( $response | ConvertTo-Json -Depth 3 )"
    }
    catch {
        Write-Host "[$counter/$total] Error: Could not create filesystem '$fsName'. $_"
    }
}
