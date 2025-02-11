# PowerStore File System Creation Scripts

A collection of PowerShell scripts for automated file system creation on Dell PowerStore arrays, providing both PowerShell module and REST API approaches.

## Available Scripts

1. `ps_fs_creation.ps1` - Uses Dell PowerStore PowerShell module
2. `RESTAPI_fs_ps.ps1` - Uses PowerStore REST API directly

## Script Comparison

| Feature | PowerShell Module Script | REST API Script |
|---------|-------------------------|-----------------|
| Dependencies | Requires Dell.PowerStore module | No external modules required |
| Authentication | Handled by module | Basic authentication |
| Certificate Handling | Managed by module | Manual SSL bypass |
| Performance | Standard | Potentially faster for bulk operations |
| Maintenance | Easier to maintain | Requires API knowledge |

## Prerequisites

### PowerShell Module Script
- PowerShell 5.1 or later
- Dell.PowerStore PowerShell module
- Network access to PowerStore management interface
- Admin credentials

### REST API Script
- PowerShell 5.1 or later
- Network access to PowerStore management interface (port 443)
- Admin credentials
- Understanding of PowerStore REST API

## Input CSV Format

### PowerShell Module Script
```csv
FileSystemName,NAS_ServerName,CapacityGB,QuotaGB,Description,ConfigType,AccessPolicy
```

### REST API Script
```csv
FileSystemName,Protocol,NAS_ServerName,CapacityGB,QuotaGB
```

Key differences:
- REST API script includes Protocol column (defaults to "smb")
- Module script has additional columns for Description, ConfigType, and AccessPolicy

## REST API Script Notes

The REST API script (`RESTAPI_fs_ps.ps1`) has several areas that could be improved:

1. Authentication
   ```powershell
   # Current (Not Recommended)
   Invoke-RestMethod -Credential $cred

   # Recommended
   # Use token-based authentication
   $tokenUrl = "https://$clusterIP/api/rest/auth/token"
   $token = Invoke-RestMethod -Uri $tokenUrl -Method Post -Credential $cred
   $headers = @{
       "Authorization" = "Bearer $($token.access_token)"
       "Accept" = "application/json"
       "x-api-version" = "1"
   }
   ```

2. API Path
   ```powershell
   # Current
   $apiUrl = "https://$clusterIP/api/rest/nas_server/$($nas.id)/fileSystem"

   # Recommended
   $apiUrl = "https://$clusterIP/api/rest/v1/nas_server/$($nas.id)/fileSystem"
   ```

3. Error Handling
   ```powershell
   # Recommended addition
   $retryCount = 3
   $retryDelay = 5
   $attempt = 0
   do {
       try {
           $result = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonPayload
           break
       }
       catch {
           $attempt++
           if ($attempt -eq $retryCount) { throw }
           Start-Sleep -Seconds $retryDelay
       }
   } while ($attempt -lt $retryCount)
   ```

## Recommendations

1. Use the PowerShell module script (`ps_fs_creation.ps1`) when:
   - You need simpler maintenance
   - You want built-in error handling
   - You need additional file system properties

2. Use the REST API script (`RESTAPI_fs_ps.ps1`) when:
   - You need better performance for bulk operations
   - You can't install the PowerShell module
   - You need customised error handling

## Security Considerations

1. Certificate Handling
   - Don't use global SSL bypass
   - Properly handle certificates or use -SkipCertificateCheck selectively

2. Authentication
   - Use token-based authentication
   - Implement token refresh
   - Don't store credentials

3. Error Handling
   - Implement retries for transient failures
   - Log specific error codes
   - Handle rate limiting

## Usage

1. PowerShell Module Script:
```powershell
.\ps_fs_creation.ps1
```

2. REST API Script:
```powershell
.\RESTAPI_fs_ps.ps1
```

Both scripts will:
1. Prompt for PowerStore management IP
2. Request credentials
3. List available NAS servers
4. Process CSV file
5. Generate HTML report

## Output

Both scripts generate HTML reports including:
- Cluster name
- Execution timestamp
- Results table with:
  - File system name
  - NAS server name
  - Creation status
  - Detailed messages

## Contributing

When contributing improvements:
1. Consider both scripts when making changes
2. Maintain consistent error handling
3. Update documentation for both approaches
4. Test with various CSV configurations
