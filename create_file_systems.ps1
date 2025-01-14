# PowerStore Configuration
$BaseUrl = "https://<MGMT_IP_ADDRESS>/api/rest"
$Username = "<USERNAME>"
$Password = "<PASSWORD>"
$CsvFile = "file_systems.csv"

# Ignore SSL warnings
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Function to get NAS server ID by name
function Get-NasServerId {
    param([string]$NasName)
    $url = "$BaseUrl/nas_servers"
    $response = Invoke-RestMethod -Uri $url -Method Get -Credential (New-Object System.Management.Automation.PSCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))) -SkipCertificateCheck

    foreach ($nas in $response) {
        if ($nas.name -eq $NasName) {
            return $nas.id
        }
    }
    Write-Host "NAS server '$NasName' not found."
    return $null
}

# Function to create a file system
function Create-FileSystem {
    param(
        [string]$NasServerId,
        [string]$FileSystemName,
        [int]$Size,
        [string]$Protocol,
        [string]$Quota
    )
    $url = "$BaseUrl/file_systems"
    $body = @{
        name = $FileSystemName
        nas_server_id = $NasServerId
        size_total = $Size
        default_access = $Protocol
    }
    if ($Quota) {
        $body.quota = [int]$Quota
    }
    $bodyJson = $body | ConvertTo-Json -Depth 10
    $response = Invoke-RestMethod -Uri $url -Method Post -Credential (New-Object System.Management.Automation.PSCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))) -Body $bodyJson -ContentType "application/json" -SkipCertificateCheck

    if ($response) {
        Write-Host "File system '$FileSystemName' created successfully."
    } else {
        Write-Host "Failed to create file system '$FileSystemName'."
    }
}

# Main Script
Import-Csv $CsvFile | ForEach-Object {
    $NasName = $_.NAS_Name
    $FileSystemName = $_.FileSystemName
    $Size = [int]$_.Size
    $Protocol = $_.Protocol
    $Quota = $_.Quota

    Write-Host "Processing file system '$FileSystemName' for NAS '$NasName'..."
    $NasServerId = Get-NasServerId -NasName $NasName
    if ($NasServerId) {
        Create-FileSystem -NasServerId $NasServerId -FileSystemName $FileSystemName -Size $Size -Protocol $Protocol -Quota $Quota
    } else {
        Write-Host "Skipping file system creation for '$FileSystemName'."
    }
}