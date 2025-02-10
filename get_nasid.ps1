[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { param($sender, $certificate, $chain, $sslPolicyErrors) $true }

$clusterMgmtIP = "your_powerstore_cluster_ip" # Replace with your PowerStore cluster management IP
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
