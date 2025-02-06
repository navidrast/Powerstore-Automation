# PowerStore Automation Scripts Repository

<div align="center">

![PowerStore](https://img.shields.io/badge/Dell-PowerStore-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Python](https://img.shields.io/badge/Python-3.x-yellow)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)

</div>

A comprehensive collection of automation scripts for Dell PowerStore arrays, featuring both Python and PowerShell implementations for maximum flexibility.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Python Scripts](#python-scripts)
  - [Installation](#python-installation)
  - [File System Creation](#python-filesystem-creation)
  - [NAS Server Management](#python-nas-management)
- [PowerShell Scripts](#powershell-scripts)
  - [Installation](#powershell-installation)
  - [File System Creation](#powershell-filesystem-creation)
  - [Replication Tasks](#powershell-replication)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

### PowerStore Array Requirements
- PowerStore OS version 2.0 or later
- REST API access enabled
- Management IP address configured
- API user account with the following roles:
  - Storage Administrator
  - Storage Operator (minimum for read operations)

### Network Requirements
- HTTPS access to PowerStore array (Port 443)
- DNS resolution for PowerStore management IP
- Jump host with access to PowerStore management network

## Python Scripts

### Python Installation

1. Ensure Python 3.x is installed:
```bash
python --version
```

2. Install required dependencies:
```bash
pip install -r requirements.txt
```

Dependencies list (`requirements.txt`):
```text
requests>=2.25.1
pandas>=1.2.0
PyYAML>=5.4.1
cryptography>=3.4.7
```

### Python Filesystem Creation

#### Script: create_file_systems.py

This script automates file system creation using PowerStore's REST API.

##### Configuration

1. Create your CSV configuration file (`file_systems.csv`):
```csv
NAS_Name,NAS_IP,FileSystemName,Size,Quota,Protocol,Description
NAS1,192.168.1.10,FileSystem1,107374182400,,nfs,Production Data
NAS2,192.168.1.11,FileSystem2,53687091200,1000000000,smb,Development Share
```

2. Update configuration in `config.yaml`:
```yaml
powerstore:
  hostname: "powerstore.example.com"
  username: "api_user"
  verify_ssl: false
  
logging:
  level: "INFO"
  file: "powerstore_operations.log"
```

##### Usage
```bash
python create_file_systems.py --config config.yaml --csv file_systems.csv
```

##### Features
- Parallel file system creation
- Detailed logging
- Error handling with retry mechanism
- Size conversion utilities
- Protocol-specific optimisations

### Python NAS Management

#### Script: manage_nas_servers.py

Comprehensive NAS server management tool supporting creation, modification, and deletion operations.

##### Configuration Format
```yaml
nas_servers:
  - name: "NAS_PRD"
    ip: "192.168.1.100"
    subnet_mask: "255.255.255.0"
    gateway: "192.168.1.1"
    domain: "example.com"
  - name: "NAS_DEV"
    ip: "192.168.1.101"
    subnet_mask: "255.255.255.0"
    gateway: "192.168.1.1"
    domain: "dev.example.com"
```

##### Usage
```bash
python manage_nas_servers.py --action create --config nas_config.yaml
python manage_nas_servers.py --action delete --name NAS_DEV
```

## PowerShell Scripts

### PowerShell Installation

#### Requirements
- PowerShell 5.1 or PowerShell Core 7.x
- PowerStore PowerShell Module

```powershell
# Install PowerStore Module
Install-Module -Name DellPowerStore -Scope CurrentUser
```

### PowerShell Filesystem Creation

#### Script: create_file_systems.ps1

Automates file system creation using PowerShell and native PowerStore cmdlets.

##### Input CSV Structure
```csv
NAS_Name,NAS_IP,FileSystemName,Size,Quota,Protocol,AccessPolicy
NAS1,192.168.1.10,FileSystem1,107374182400,,nfs,UNIX
NAS2,192.168.1.11,FileSystem2,53687091200,1000000000,smb,NATIVE
```

##### Features
- Progress tracking with status bar
- Detailed error handling
- Parallel execution support
- Size validation and conversion
- Protocol-specific configuration

##### Usage
```powershell
.\create_file_systems.ps1 -CsvPath .\file_systems.csv -Parallel
```

### PowerShell Replication

#### Script: replication_tasks.ps1

Manages replication relationships between PowerStore arrays.

##### Configuration Example
```powershell
$replicationConfig = @{
    SourceArray      = "powerstore-1.example.com"
    DestinationArray = "powerstore-2.example.com"
    RPO             = "5minutes"
    FileSystems     = @("FS_PRD", "FS_HR")
}
```

##### Features
- RPO management
- Automated failover testing
- Replication health monitoring
- Bandwidth throttling
- Alert configuration

##### Usage
```powershell
.\replication_tasks.ps1 -ConfigFile .\replication_config.json -ValidateOnly
.\replication_tasks.ps1 -ConfigFile .\replication_config.json -Execute
```

## Error Handling

Both Python and PowerShell scripts implement comprehensive error handling:

```python
try:
    # Operation code
except PowerStoreException as e:
    logging.error(f"PowerStore error: {e.message}")
    if e.error_code in RETRYABLE_ERRORS:
        retry_operation()
except Exception as e:
    logging.error(f"Unexpected error: {str(e)}")
```

```powershell
try {
    # Operation code
} catch [DellPowerStoreException] {
    Write-Error "PowerStore error: $_"
    if ($_.ErrorCode -in $retryableErrors) {
        Invoke-RetryOperation
    }
} catch {
    Write-Error "Unexpected error: $_"
}
```

## Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This repository is licensed under the MIT License. See the [LICENSE](./LICENSE) file for more details.

---
<div align="center">
Made with ❤️ for PowerStore automation

[Report Bug](../../issues) · [Request Feature](../../issues)
</div>
