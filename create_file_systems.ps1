# Prompt for PowerStore connection details
$powerstoreIP = Read-Host "Enter PowerStore IP address"
$username = Read-Host "Enter username"
$password = Read-Host "Enter password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

# Define the CSV file path
$csvFile = "file_systems.csv"
if (-Not (Test-Path $csvFile)) {
    Write-Host "Error: CSV file '$csvFile' not found."
    exit
}

# Import CSV file
$fileSystems = Import-Csv -Path $csvFile
$total = $fileSystems.Count
Write-Host "Starting creation of $total filesystems..."

$counter = 0
foreach ($fs in $fileSystems) {
    $counter++
    $fsName = $fs.FileSystemName
    
    # Update progress bar
    Write-Progress -Activity "Creating File Systems" `
                   -Status "Processing '$fsName'" `
                   -PercentComplete (($counter / $total) * 100)
    
    Write-Host "[$counter/$total] Pending: Creating filesystem '$fsName'..."
    
    try {
        # Construct the API endpoint URL
        $url = "https://$powerstoreIP/api/v1/filesystems"
        
        # Build the request body as a hashtable
        $body = @{
            NAS_Name       = $fs.NAS_Name
            NAS_IP         = $fs.NAS_IP
            FileSystemName = $fs.FileSystemName
            Size           = [long]$fs.Size    # Changed from [int] to [long]
            Protocol       = $fs.Protocol
        }
        # Include Quota if provided
        if ($fs.Quota -and $fs.Quota.Trim() -ne "") {
            $body.Quota = [long]$fs.Quota     # Changed from [int] to [long]
        }
        
        # Convert the hashtable to JSON
        $jsonBody = $body | ConvertTo-Json
        
        # Invoke REST API (Skip certificate check for self-signed certificates)
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $jsonBody `
                    -ContentType "application/json" -Credential $cred -SkipCertificateCheck
        Write-Host "[$counter/$total] Completed: Filesystem '$fsName' created. Response: $( $response | ConvertTo-Json -Depth 3 )"
    }
    catch {
        Write-Host "[$counter/$total] Error: Could not create filesystem '$fsName'. $_"
    }
}
