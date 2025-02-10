[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { param($sender, $certificate, $chain, $sslPolicyErrors) $true }

$clusterMgmtIP = "your_powerstore_cluster_ip" # Replace with your PowerStore cluster management IP

$cred = Get-Credential -Message "Enter PowerStore admin credentials"

$nasUrl = "https://$clusterMgmtIP/api/rest/v3/nas_servers" # Correct API endpoint for NAS servers

try {
    $nasList = Invoke-RestMethod -Uri $nasUrl -Method Get -Credential $cred
    Write-Host "NAS Servers:"
    $nasList.entities | Format-Table id, name, type # Display ID, name, and type

    # Option 1: Choose interactively (if you have a few NAS servers)
    $nasID = Read-Host "Enter the ID of the NAS server you want to use"

    # Option 2: Filter by name (useful if you know the NAS server name)
    # Example: $nasID = ($nasList.entities | Where-Object {$_.name -eq "YourNASServerName"}).id
    # If the name is not found, $nasID will be $null.  Handle this case:
    # if ($nasID -eq $null) {
    #     Write-Error "NAS server 'YourNASServerName' not found."
    #     return
    # }

    Write-Host "NAS Server ID: $nasID" # Output the selected NAS ID
}
catch {
    Write-Error "Error getting NAS servers: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.Value__)"
        Write-Host "Response Body: $($_.Exception.Response.Content.ReadAsString())"
    }
}
