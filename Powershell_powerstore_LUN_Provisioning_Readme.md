- **Memory**: Minimum 512MB RAM available for PowerShell
- **Storage**: 100MB free space for logs and reports

### PowerStore Requirements
- **PowerStore OS**: 1.0 or higher
- **User Account**: With appropriate permissions (see [Security Considerations](#security-considerations))
- **Network Access**: HTTPS access to PowerStore management IP
- **API Access**: REST API enabled (default)

### Required Permissions
Your PowerStore user account needs these minimum permissions:
- **Storage Provisioning**: Create/modify volumes
- **Host Management**: View and modify host mappings
- **Configuration**: Read storage pools, hosts, and file systems
- **Monitoring**: Read performance and capacity metrics

## Installation

### Step 1: Download Scripts

Download the following files to your working directory:
- `PowerStore-LUN-Provision.ps1`
- `PowerStore-Report-Generator.ps1`
- `README.md` (this file)

### Step 2: Set Execution Policy

If running on Windows, you may need to adjust the PowerShell execution policy:

```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy to allow local scripts (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Alternative: Bypass execution policy for specific session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Step 3: Verify PowerShell Version

Check your PowerShell version:

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Should show 5.1 or higher
```

### Step 4: Test Network Connectivity

Verify connectivity to your PowerStore array:

```powershell
# Test basic connectivity (replace with your PowerStore IP)
Test-NetConnection -ComputerName "192.168.1.100" -Port 443

# Test HTTPS connectivity
try {
    Invoke-WebRequest -Uri "https://192.168.1.100" -UseBasicParsing
    Write-Host "HTTPS connectivity successful" -ForegroundColor Green
} catch {
    Write-Host "HTTPS connectivity failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

## Configuration

### Step 1: Create Configuration File

Generate a sample configuration file:

```powershell
.\PowerStore-LUN-Provision.ps1 -CreateSampleConfig
```

This creates `config.json` with the following structure:

```json
{
  "PowerStore": {
    "ManagementIP": "192.168.1.100",
    "Username": "admin",
    "Password": "your_password_here",
    "VerifySSL": false
  },
  "Logging": {
    "Level": "INFO",
    "LogFile": "PowerStore-Provision.log"
  }
}
```

### Step 2: Update Configuration

Edit `config.json` with your PowerStore details:

1. **ManagementIP**: Your PowerStore management IP address
2. **Username**: PowerStore username with provisioning permissions
3. **Password**: PowerStore user password
4. **VerifySSL**: Set to `true` for production environments

### Step 3: Test Connection

Verify connectivity:

```powershell
.\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -GetInventory
```

If successful, you'll see current LUN inventory displayed.

## Quick Start Guide

### 1. Generate Sample CSV Template

```powershell
.\PowerStore-LUN-Provision.ps1 -CreateSampleCSV
```

This creates `sample_luns.csv` with the correct format.

### 2. Edit CSV File

Open `sample_luns.csv` in Excel or notepad and modify according to your requirements:

```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
prod_app_lun_01,1024,Pool0,Production application data,apphost1;apphost2,Yes
dev_db_lun_01,512,Pool0,Development database,devhost1,Yes
```

### 3. Provision LUNs

```powershell
.\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -InputCSV "sample_luns.csv" -OutputReport "provision_report.csv"
```

### 4. Review Results

Check the console output and `provision_report.csv` for detailed results.

## Detailed Usage Instructions

### LUN Provisioning Script

#### Basic Syntax

```powershell
.\PowerStore-LUN-Provision.ps1 [Parameters]
```

#### Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `-ConfigFile` | String | No | Configuration file path | `-ConfigFile "config.json"` |
| `-InputCSV` | String | No | Input CSV file with LUN specifications | `-InputCSV "luns.csv"` |
| `-OutputReport` | String | No | Output CSV file for provision report | `-OutputReport "report.csv"` |
| `-GetInventory` | Switch | No | Get current LUN inventory | `-GetInventory` |
| `-CreateSampleCSV` | Switch | No | Create sample CSV file | `-CreateSampleCSV` |
| `-CreateSampleConfig` | Switch | No | Create sample config file | `-CreateSampleConfig` |

#### Step-by-Step Provisioning Process

**1. Prepare Your Environment**
```powershell
# Create working directory
New-Item -ItemType Directory -Path "C:\PowerStore-Automation" -Force
Set-Location "C:\PowerStore-Automation"

# Generate configuration template
.\PowerStore-LUN-Provision.ps1 -CreateSampleConfig
```

**2. Configure Connection**
```powershell
# Edit config.json with your PowerStore details
notepad config.json
# OR use PowerShell ISE
ise config.json
```

**3. Test Connectivity**
```powershell
# Verify connection and view current inventory
.\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -GetInventory
```

**4. Create LUN Specification**
```powershell
# Generate sample CSV template
.\PowerStore-LUN-Provision.ps1 -CreateSampleCSV

# Edit sample_luns.csv with your requirements
notepad sample_luns.csv
```

**5. Validate Your CSV**
Ensure your CSV includes:
- Valid storage pool names (check with `-GetInventory`)
- Existing host names (if specifying host attachments)
- Unique LUN names
- Appropriate sizes for available capacity

**6. Execute Provisioning**
```powershell
# Provision LUNs with detailed reporting
.\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -InputCSV "sample_luns.csv" -OutputReport "provision_report.csv"
```

**7. Review Results**
```powershell
# Check console output for summary
# Review provision_report.csv for detailed results
Import-Csv "provision_report.csv" | Format-Table -AutoSize

# Check log file for detailed logs
Get-Content "PowerStore-Provision-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 20
```

### Report Generator Script

#### Basic Syntax

```powershell
.\PowerStore-Report-Generator.ps1 [Parameters]
```

#### Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `-ConfigFile` | String | No | Configuration file path | `-ConfigFile "config.json"` |
| `-OutputDirectory` | String | No | Output directory for reports | `-OutputDirectory "reports"` |
| `-AllReports` | Switch | No | Generate all report types | `-AllReports` |
| `-LUNsOnly` | Switch | No | Generate LUNs report only | `-LUNsOnly` |
| `-HostsOnly` | Switch | No | Generate hosts report only | `-HostsOnly` |
| `-PoolsOnly` | Switch | No | Generate storage pools report only | `-PoolsOnly` |
| `-FileSystemsOnly` | Switch | No | Generate file systems report only | `-FileSystemsOnly` |
| `-NFSOnly` | Switch | No | Generate NFS shares report only | `-NFSOnly` |

#### Step-by-Step Report Generation

**1. Generate All Reports**
```powershell
# Create comprehensive report suite
.\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -AllReports -OutputDirectory "reports"
```

**2. Generate Specific Reports**
```powershell
# LUNs only
.\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -LUNsOnly

# Storage pools only
.\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -PoolsOnly

# Hosts only
.\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -HostsOnly
```

**3. Review Generated Reports**
```powershell
# Navigate to reports directory
Set-Location "reports"

# List generated files
Get-ChildItem -Filter "*.csv" | Sort-Object LastWriteTime -Descending

# Preview a report
Import-Csv "PowerStore_LUNs_TableExportData_2025_06_02_14_30_15.csv" | Select-Object -First 10 | Format-Table
```

## CSV File Formats

### LUN Provisioning CSV Format

**File**: `luns_to_provision.csv`

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| Name | String | Yes | Unique LUN name | `prod_app_lun_01` |
| Size_GB | Number | Yes | LUN size in GB | `1024` |
| Pool | String | Yes | Storage pool name | `Pool0` |
| Description | String | No | LUN description | `Production application data` |
| Host_Names | String | No | Semicolon-separated host names | `host1;host2;host3` |
| Thin_Provisioned | String | No | Yes/No for thin provisioning | `Yes` |

**Example CSV Content**:
```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
prod_web_lun_01,512,Pool0,Web server storage,webhost1;webhost2,Yes
prod_db_lun_01,2048,Pool0,Database storage,dbhost1,Yes
backup_lun_01,5120,Pool1,Backup storage,,No
test_app_lun_01,256,Pool0,Test application,testhost1,Yes
```

### Important CSV Guidelines

1. **No Empty Required Fields**: Name, Size_GB, and Pool are mandatory
2. **Unique Names**: LUN names must be unique across the PowerStore array
3. **Valid Pool Names**: Pool names must exist (check with `-GetInventory`)
4. **Host Names**: Must match exactly with PowerStore host registrations
5. **Size Limits**: Respect storage pool capacity limits
6. **Character Encoding**: Use UTF-8 encoding
7. **No Special Characters**: Avoid special characters in names (use alphanumeric, hyphens, underscores)

## Report Outputs

### LUN Provisioning Report

**File**: `provision_report.csv`

Contains detailed results for each LUN provisioning attempt:

| Column | Description |
|--------|-------------|
| Name | LUN name from CSV |
| Status | SUCCESS, FAILED, or VALIDATION_FAILED |
| Message | Detailed status message |
| LUN_ID | PowerStore LUN ID (if successful) |
| WWN | LUN World Wide Name |
| Size_GB | Requested size in GB |
| Pool | Storage pool used |
| Hosts_Attached | Successfully attached hosts (semicolon-separated) |
| Timestamp | Provision attempt timestamp |

### Inventory Reports

The report generator creates files matching your existing CSV export format:

1. **LUNs Report**: `{Array}_LUNs_TableExportData_{timestamp}.csv`
2. **Hosts Report**: `{Array}_Hosts_TableExportData_{timestamp}.csv`
3. **Storage Pools Report**: `{Array}_StoragePools_TableExportData_{timestamp}.csv`
4. **File Systems Report**: `{Array}_FileSystems_TableExportData_{timestamp}.csv`
5. **NFS Shares Report**: `{Array}_NFSShares_TableExportData_{timestamp}.csv`

### Console Output Examples

#### Successful Provisioning
```
============================================================
PowerStore LUN Provisioning Report
============================================================
Total LUN requests: 3
Successful: 3
Failed: 0
Success rate: 100.0%
============================================================
✓ prod_web_lun_01 - SUCCESS
  WWN: 60:06:01:60:16:D0:48:00:3F:1A:24:5D:B1:02:0F:45
  Attached to hosts: webhost1, webhost2
✓ prod_db_lun_01 - SUCCESS
  WWN: 60:06:01:60:16:D0:48:00:E3:A5:C8:5D:E9:CB:34:3F
  Attached to hosts: dbhost1
✓ backup_lun_01 - SUCCESS
  WWN: 60:06:01:60:16:D0:48:00:A1:B2:C3:4D:5E:6F:78:90
```

#### Failed Provisioning
```
✗ invalid_lun_01 - VALIDATION_FAILED
  Message: Storage pool 'InvalidPool' does not exist
✗ duplicate_lun_01 - FAILED
  Message: Failed to create LUN: Volume name already exists
```

## Troubleshooting

### Common Issues and Solutions

#### 1. PowerShell Execution Policy Issues

**Error**: `cannot be loaded because running scripts is disabled on this system`

**Solutions**:
```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Alternative: Bypass for current session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run script with bypass (one-time)
powershell.exe -ExecutionPolicy Bypass -File ".\PowerStore-LUN-Provision.ps1" -ConfigFile "config.json" -GetInventory
```

#### 2. Connection Issues

**Error**: `Failed to connect to PowerStore`

**Solutions**:
```powershell
# Check network connectivity
Test-NetConnection -ComputerName "192.168.1.100" -Port 443

# Verify PowerStore management interface accessibility
try {
    $response = Invoke-WebRequest -Uri "https://192.168.1.100" -UseBasicParsing -TimeoutSec 10
    Write-Host "PowerStore web interface accessible" -ForegroundColor Green
} catch {
    Write-Host "PowerStore web interface not accessible: $($_.Exception.Message)" -ForegroundColor Red
}

# Test SSL/TLS connectivity
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

#### 3. Authentication Failures

**Error**: `Authentication failed`

**Solutions**:
```powershell
# Verify credentials in config.json
$config = Get-Content "config.json" | ConvertFrom-Json
Write-Host "Username: $($config.PowerStore.Username)"
Write-Host "Management IP: $($config.PowerStore.ManagementIP)"

# Test credentials manually via PowerStore Manager web interface
Start-Process "https://$($config.PowerStore.ManagementIP)"

# Check if account is locked or password expired
# Contact PowerStore administrator if needed
```

#### 4. SSL Certificate Issues

**Error**: `The underlying connection was closed: Could not establish trust relationship`

**Solutions**:
```powershell
# For testing environments, disable SSL verification in config.json
{
  "PowerStore": {
    "VerifySSL": false
  }
}

# For production, add PowerStore certificate to trusted store
# Export certificate from PowerStore Manager and install it

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

#### 5. CSV Format Errors

**Error**: `Missing required field` or `Invalid CSV format`

**Solutions**:
```powershell
# Generate new sample CSV
.\PowerStore-LUN-Provision.ps1 -CreateSampleCSV

# Validate CSV structure
$csv = Import-Csv "your_file.csv"
$csv | Get-Member
$csv | Select-Object -First 5 | Format-Table

# Check for required columns
$requiredColumns = @("Name", "Size_GB", "Pool")
$csvColumns = ($csv | Get-Member -MemberType NoteProperty).Name
$missingColumns = $requiredColumns | Where-Object { $_ -notin $csvColumns }
if ($missingColumns) {
    Write-Host "Missing required columns: $($missingColumns -join ', ')" -ForegroundColor Red
}
```

#### 6. Storage Pool Issues

**Error**: `Storage pool 'PoolX' does not exist`

**Solutions**:
```powershell
# List available pools
.\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -GetInventory | Select-Object Name, Pool | Sort-Object Pool -Unique

# Check pool names match exactly (case-sensitive)
# Update CSV with correct pool names
```

#### 7. Host Mapping Issues

**Error**: `Host 'hostname' does not exist`

**Solutions**:
```powershell
# Generate hosts report to see available hosts
.\PowerStore-Report-Generator.ps1 -ConfigFile "config.json" -HostsOnly

# Check exact host names in PowerStore
$hostsReport = Import-Csv "PowerStore_Hosts_TableExportData_*.csv"
$hostsReport | Select-Object Name | Sort-Object Name

# Leave Host_Names column empty if not mapping immediately
# Map hosts manually after LUN creation if needed
```

### Debug Mode and Logging

#### Enable Verbose Logging

```powershell
# Run with verbose output
.\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -InputCSV "luns.csv" -OutputReport "report.csv" -Verbose

# Check log files
Get-ChildItem -Filter "PowerStore-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# View recent log entries
Get-Content "PowerStore-Provision-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 50

# Search for errors in logs
Select-String -Path "PowerStore-Provision-*.log" -Pattern "ERROR" | Select-Object -Last 10
```

#### PowerShell Debugging

```powershell
# Add debug statements to script (for troubleshooting)
$DebugPreference = "Continue"
Write-Debug "Debug information here"

# Use try-catch for detailed error information
try {
    # Your code here
} catch {
    Write-Host "Error details:" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
}
```

## Advanced Configuration

### Environment Variables

Store sensitive information in environment variables instead of configuration files:

```powershell
# Set environment variables (Windows)
[Environment]::SetEnvironmentVariable("POWERSTORE_PASSWORD", "your_secure_password", "User")
[Environment]::SetEnvironmentVariable("POWERSTORE_USERNAME", "admin", "User")
[Environment]::SetEnvironmentVariable("POWERSTORE_IP", "192.168.1.100", "User")

# Set environment variables (PowerShell Core/Linux)
$env:POWERSTORE_PASSWORD = "your_secure_password"
$env:POWERSTORE_USERNAME = "admin"
$env:POWERSTORE_IP = "192.168.1.100"

# Update config.json to use environment variables
{
  "PowerStore": {
    "ManagementIP": "${env:POWERSTORE_IP}",
    "Username": "${env:POWERSTORE_USERNAME}",
    "Password": "${env:POWERSTORE_PASSWORD}",
    "VerifySSL": true
  }
}
```

### Batch Processing for Large Deployments

```powershell
# Split large CSV into smaller batches
function Split-CSVFile {
    param(
        [string]$InputFile,
        [int]$BatchSize = 50
    )
    
    $data = Import-Csv $InputFile
    $batches = [Math]::Ceiling($data.Count / $BatchSize)
    
    for ($i = 0; $i -lt $batches; $i++) {
        $start = $i * $BatchSize
        $end = [Math]::Min(($i + 1) * $BatchSize - 1, $data.Count - 1)
        $batch = $data[$start..$end]
        
        $batchFile = "batch_$($i + 1)_of_$batches.csv"
        $batch | Export-Csv -Path $batchFile -NoTypeInformation
        Write-Host "Created batch file: $batchFile"
    }
}

# Process batches sequentially
function Start-BatchProvisioning {
    param(
        [string]$ConfigFile,
        [string]$OutputDirectory = "batch_reports"
    )
    
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force
    }
    
    $batchFiles = Get-ChildItem -Filter "batch_*.csv" | Sort-Object Name
    
    foreach ($batchFile in $batchFiles) {
        Write-Host "Processing $($batchFile.Name)..." -ForegroundColor Cyan
        
        $reportFile = Join-Path $OutputDirectory "report_$($batchFile.BaseName).csv"
        
        .\PowerStore-LUN-Provision.ps1 -ConfigFile $ConfigFile -InputCSV $batchFile.FullName -OutputReport $reportFile
        
        # Brief pause between batches
        Start-Sleep -Seconds 10
    }
}

# Usage
Split-CSVFile -InputFile "large_luns.csv" -BatchSize 50
Start-BatchProvisioning -ConfigFile "config.json"
```

### Automated Scheduling with Task Scheduler

#### Create Scheduled Task (Windows)

```powershell
# Create scheduled task for daily LUN provisioning
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\PowerStore-Automation\PowerStore-LUN-Provision.ps1`" -ConfigFile `"C:\PowerStore-Automation\config.json`" -InputCSV `"C:\PowerStore-Automation\daily_luns.csv`" -OutputReport `"C:\PowerStore-Automation\daily_report.csv`""

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"

$principal = New-ScheduledTaskPrincipal -UserId "DOMAIN\ServiceAccount" -LogonType ServiceAccount

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnDemand -DontStopIfGoingOnBatteries -PowerManagement

Register-ScheduledTask -TaskName "PowerStore Daily LUN Provisioning" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Daily PowerStore LUN provisioning automation"
```

#### Create Scheduled Task for Weekly Reports

```powershell
# Create scheduled task for weekly reports
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"C:\PowerStore-Automation\PowerStore-Report-Generator.ps1`" -ConfigFile `"C:\PowerStore-Automation\config.json`" -AllReports -OutputDirectory `"C:\PowerStore-Automation\weekly_reports`""

$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At "01:00AM"

Register-ScheduledTask -TaskName "PowerStore Weekly Reports" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Weekly PowerStore inventory reports"
```

### Integration with ITSM Systems

#### ServiceNow Integration Example

```powershell
# ServiceNow PowerStore Integration Wrapper
function Invoke-ServiceNowProvisioning {
    param(
        [string]$TicketNumber,
        [hashtable]$LUNRequests
    )
    
    try {
        # Convert ServiceNow data to CSV
        $csvData = @()
        foreach ($request in $LUNRequests.GetEnumerator()) {
            $csvData += [PSCustomObject]@{
                Name = $request.Value.Name
                Size_GB = $request.Value.SizeGB
                Pool = $request.Value.Pool
                Description = "ServiceNow Ticket: $TicketNumber"
                Host_Names = $request.Value.Hosts -join ";"
                Thin_Provisioned = $request.Value.ThinProvisioned
            }
        }
        
        # Export to temporary CSV
        $tempCSV = "ServiceNow_$TicketNumber.csv"
        $csvData | Export-Csv -Path $tempCSV -NoTypeInformation
        
        # Execute provisioning
        $reportFile = "ServiceNow_Report_$TicketNumber.csv"
        .\PowerStore-LUN-Provision.ps1 -ConfigFile "config.json" -InputCSV $tempCSV -OutputReport $reportFile
        
        # Parse results and return to ServiceNow
        $results = Import-Csv $reportFile
        
        # Clean up temporary files
        Remove-Item $tempCSV -Force
        
        return $results
    }
    catch {
        Write-Error "ServiceNow provisioning failed: $($_.Exception.Message)"
        throw
    }
}
```

## Security Considerations

### User Account Security

#### Create Dedicated Service Account

```powershell
# PowerStore service account configuration recommendations
@"
Account Details:
- Username: svc_powerstore_automation
- Role: Custom role with minimum required permissions
- Description: PowerStore automation service account
- Password Policy: Strong password, 90-day rotation
- Login Restrictions: Restrict to management network IPs
"@
```

#### Minimum Required Permissions

Create a custom role in PowerStore with these permissions:
- **Volume Management**: Create, modify, delete volumes
- **Host Management**: Map/unmap volumes to hosts
- **Storage Pool**: Read access to storage pools
- **File System**: Read access for reporting
- **NAS Management**: Read access for NFS reporting

### Credential Management

#### Secure Password Storage

```powershell
# Use Windows Credential Manager for password storage
function Set-PowerStoreCredential {
    param(
        [string]$Username,
        [securestring]$Password,
        [string]$Target = "PowerStore_Automation"
    )
    
    # Store credential in Windows Credential Manager
    cmdkey /generic:$Target /user:$Username /pass:$([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)))
}

function Get-PowerStoreCredential {
    param(
        [string]$Target = "PowerStore_Automation"
    )
    
    # Retrieve credential from Windows Credential Manager
    return Get-StoredCredential -Target $Target
}

# Usage
$securePassword = Read-Host -AsSecureString -Prompt "Enter PowerStore password"
Set-PowerStoreCredential -Username "admin" -Password $securePassword
```

#### Environment-Based Configuration

```powershell
# Production configuration using environment variables
function Import-SecureConfig {
    param([string]$ConfigPath)
    
    if (Test-Path $ConfigPath) {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        
        # Override with environment variables if they exist
        if ($env:POWERSTORE_IP) { $config.PowerStore.ManagementIP = $env:POWERSTORE_IP }
        if ($env:POWERSTORE_USERNAME) { $config.PowerStore.Username = $env:POWERSTORE_USERNAME }
        if ($env:POWERSTORE_PASSWORD) { $config.PowerStore.Password = $env:POWERSTORE_PASSWORD }
        
        return $config
    }
    
    throw "Configuration file not found: $ConfigPath"
}
```

### Network Security

#### SSL/TLS Configuration

```powershell
# Force TLS 1.2 for secure communications
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# For production environments, always verify SSL certificates
$config.PowerStore.VerifySSL = $true

# Custom certificate validation (if using self-signed certificates)
function Set-CustomCertificateValidation {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {
        param($sender, $certificate, $chain, $sslPolicyErrors)
        
        # Add custom certificate validation logic here
        # Return $true only for trusted certificates
        return $sslPolicyErrors -eq [Net.Security.SslPolicyErrors]::None
    }
}
```

### File Security

#### Secure Configuration Files

```powershell
# Set restrictive permissions on configuration files
function Set-SecureFilePermissions {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        # Remove inheritance and set explicit permissions
        $acl = Get-Acl $FilePath
        $acl.SetAccessRuleProtection($true, $false)
        
        # Add current user with full control
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        
        # Add SYSTEM with full control
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM",
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($systemRule)
        
        Set-Acl -Path $FilePath -AclObject $acl
        Write-Host "Secured permissions for: $FilePath" -ForegroundColor Green
    }
}

# Usage
Set-SecureFilePermissions -FilePath "config.json"
```

#### Log File Management

```powershell
# Implement secure log rotation
function Start-LogRotation {
    param(
        [string]$LogDirectory = ".",
        [int]$MaxFiles = 10,
        [int]$MaxSizeMB = 50
    )
    
    $logFiles = Get-ChildItem -Path $LogDirectory -Filter "PowerStore-*.log" | Sort-Object LastWriteTime
    
    # Remove old log files if too many
    if ($logFiles.Count -gt $MaxFiles) {
        $filesToRemove = $logFiles | Select-Object -First ($logFiles.Count - $MaxFiles)
        $filesToRemove | Remove-Item -Force
        Write-Host "Removed $($filesToRemove.Count) old log files" -ForegroundColor Yellow
    }
    
    # Compress large log files
    foreach ($logFile in $logFiles) {
        if (($logFile.Length / 1MB) -gt $MaxSizeMB) {
            Compress-Archive -Path $logFile.FullName -DestinationPath "$($logFile.FullName).zip" -Force
            Remove-Item $logFile.FullName -Force
            Write-Host "Compressed large log file: $($logFile.Name)" -ForegroundColor Yellow
        }
    }
}
```

## Examples

### Example 1: Simple Application LUN Provisioning

**Scenario**: Provision 3 LUNs for a new web application

**Step 1**: Create CSV file (`web_app_luns.csv`)
```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
webapp_data_01,1024,Pool0,Web application data volume,webhost1;webhost2,Yes
webapp_logs_01,256,# PowerStore Automation Scripts (PowerShell)

Comprehensive Dell PowerStore LUN provisioning and reporting automation scripts written in PowerShell that match your existing CSV export formats.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Quick Start Guide](#quick-start-guide)
- [Detailed Usage Instructions](#detailed-usage-instructions)
- [CSV File Formats](#csv-file-formats)
- [Report Outputs](#report-outputs)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Security Considerations](#security-considerations)
- [Examples](#examples)

## Overview

This automation suite provides two main PowerShell scripts:

1. **`PowerStore-LUN-Provision.ps1`** - Provisions LUNs based on CSV input and generates detailed reports
2. **`PowerStore-Report-Generator.ps1`** - Generates comprehensive inventory reports matching your existing CSV exports

Both scripts use PowerStore REST API directly and support your existing data formats without requiring additional Python dependencies.

## Prerequisites

### System Requirements
- **PowerShell**: 5.1 or higher (Windows PowerShell or PowerShell Core)
- **Operating System**: Windows 10/11, Windows Server 2016+, or PowerShell Core on Linux/macOS
- **Network**: HTTPS connectivity to PowerStore management interface
- **Memory**:
