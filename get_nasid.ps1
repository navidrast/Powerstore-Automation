[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # Or the appropriate TLS version

# Prompt for PowerStore IP address
$clusterMgmtIP = Read-Host "Enter the PowerStore cluster management IP address"

# Validate IP address (basic check)
if ($clusterMgmtIP -match "^({1,3}\.){3}{1,3}$") {
    Write-Host "Using PowerStore IP: $clusterMgmtIP"
} else {
    Write-Error "Invalid IP address format."
    return # Exit the script
}

# ***DANGER: ONLY USE IN ISOLATED TEST ENVIRONMENTS***
# Bypass certificate validation (INSECURE - DO NOT USE IN PRODUCTION)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { param($sender, $certificate, $chain, $sslPolicyErrors) $true }

$outputFile = "C:\path\to\your\nas_server_ids.csv"  # Replace with desired path for the CSV file

$cred = Get-Credential -Message "Enter PowerStore admin credentials"

$nasUrl = "https://$clusterMgmtIP/api/rest/v3/nas_servers"

try {
    $nasList = Invoke-RestMethod -Uri $nasUrl -Method Get -Credential $cred

    # Output to CSV: id, name, type
    $nasList.entities | Select-Object id, name, type | Export-Csv -Path $outputFile -NoTypeInformation

    Write-Host "NAS server IDs saved to: $outputFile"

    # Optional: Display the NAS servers in the console as well
    Write-Host "NAS Servers:"
    $nasList.entities | Format-Table id, name, type

}
catch {
    Write-Error "Error getting NAS servers: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.Value__)"
        Write-Host "Response Body: $($_.Exception.Response.Content.ReadAsString())"
    }
}

Write-Host "" # Add an empty line for better readability
Write-Warning "***SECURITY WARNING***: Certificate validation is DISABLED.  This script is ONLY safe to use in a completely isolated, non-production, testing environment.  Do NOT use this in production.  Import the PowerStore's certificate to establish a secure connection."
