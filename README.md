# PowerStore Automation Scripts Repository

![PowerStore](https://img.shields.io/badge/Dell-PowerStore-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Python](https://img.shields.io/badge/Python-3.x-yellow)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)

An extensive suite of automation tools designed for Dell PowerStore arrays. This repository includes both Python and PowerShell scripts to streamline operations, enhance configuration management, and simplify replication tasks—all tailored for modern storage environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Python Scripts](#python-scripts)
  - [Installation](#python-installation)
  - [File System Provisioning](#python-filesystem-provisioning)
  - [NAS Server Operations](#python-nas-operations)
- [PowerShell Scripts](#powershell-scripts)
  - [Installation](#powershell-installation)
  - [File System Provisioning](#powershell-filesystem-provisioning)
  - [Replication Management](#powershell-replication-management)
- [Error Handling](#error-handling)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

### PowerStore Array Requirements

- PowerStore OS version 2.0 or newer
- REST API access must be enabled
- A properly configured management IP address
- An API user account with at least the following roles:
  - Storage Administrator
  - Storage Operator (for read-only operations)

### Network Requirements

- Secure HTTPS access (Port 443) to the PowerStore array
- Reliable DNS resolution for the management IP
- Access via a dedicated jump host if required by your network architecture

## Python Scripts

### Python Installation

1. Confirm that Python 3.x is installed:

```bash
python --version
```

2. Install the necessary dependencies:

```bash
pip install -r requirements.txt
```

The `requirements.txt` includes:
- requests>=2.25.1
- pandas>=1.2.0
- PyYAML>=5.4.1
- cryptography>=3.4.7

### Python Filesystem Provisioning

Script: `create_file_systems.py`

This tool provisions file systems on your PowerStore array using its REST API. It processes configuration details from a CSV file and uses a YAML file to define connection parameters and logging settings.

#### Configuration

Prepare a CSV file (`file_systems.csv`) with the following structure:

```csv
NAS_Name,NAS_IP,FileSystemName,Size,Quota,Protocol,Description
NAS_Main,192.168.100.10,ProdFS,107374182400,,nfs,Primary Production Data
NAS_Backup,192.168.100.11,BackupFS,53687091200,2000000000,smb,Secondary Backup Share
```

Adjust the YAML configuration file (`config.yaml`) as needed:

```yaml
powerstore:
  hostname: "powerstore.company.com"
  username: "api_user"
  verify_ssl: false

logging:
  level: "DEBUG"
  file: "automation.log"
```

#### Usage

Run the script with:

```bash
python create_file_systems.py --config config.yaml --csv file_systems.csv
```

#### Key Features

- Concurrent provisioning of file systems for efficiency
- Comprehensive logging to track each operation
- Robust retry mechanisms to handle transient failures
- Utility functions for size conversion and protocol optimisations

### Python NAS Server Operations

Script: `manage_nas_servers.py`

This script manages NAS server configurations on PowerStore. It supports creation, updates, and deletions based on a structured YAML configuration file.

#### Configuration Format

Define your NAS server settings in a YAML file (e.g., `nas_config.yaml`):

```yaml
nas_servers:
  - name: "NAS_Enterprise"
    ip: "192.168.200.100"
    subnet_mask: "255.255.255.0"
    gateway: "192.168.200.1"
    domain: "enterprise.company.com"
  - name: "NAS_Test"
    ip: "192.168.200.101"
    subnet_mask: "255.255.255.0"
    gateway: "192.168.200.1"
    domain: "test.company.com"
```

#### Usage

Execute the following commands for server operations:

```bash
python manage_nas_servers.py --action create --config nas_config.yaml
python manage_nas_servers.py --action delete --name NAS_Test
```

## PowerShell Scripts

### PowerShell Installation

#### Requirements

- PowerShell 5.1 or PowerShell Core 7.x
- Dell PowerStore PowerShell Module installed

To install the module:

```powershell
# Install the Dell PowerStore module for current user
Install-Module -Name DellPowerStore -Scope CurrentUser
```

### PowerShell Filesystem Provisioning

Script: `create_file_systems.ps1`

This script automates the creation of file systems using native PowerStore cmdlets. It reads configuration details from a CSV file and supports parallel processing.

#### Input CSV Structure

Your CSV file should resemble:

```csv
NAS_Name,NAS_IP,FileSystemName,Size,Quota,Protocol,AccessPolicy
NAS_Main,192.168.100.10,ProdFS,107374182400,,nfs,UNIX
NAS_Backup,192.168.100.11,BackupFS,53687091200,2000000000,smb,NATIVE
```

#### Features

- Visual progress indicators for long-running operations
- Detailed error capture and logging
- Parallel execution to expedite bulk provisioning
- Input validation for sizes and protocol-specific configurations

#### Usage

Run the script as follows:

```powershell
.\create_file_systems.ps1 -CsvPath .\file_systems.csv -Parallel
```

### PowerShell Replication Management

Script: `replication_tasks.ps1`

This script facilitates the management of replication settings between PowerStore arrays. It supports both simulation (validation) and full execution modes.

#### Configuration Example

Configure your replication settings in a JSON file (or pass a PowerShell hash table):

```powershell
$replicationConfig = @{
    SourceArray      = "powerstore-1.company.com"
    DestinationArray = "powerstore-2.company.com"
    RPO              = "5minutes"
    FileSystems      = @("ProdFS", "BackupFS")
}
```

#### Features

- Configurable RPO settings and automated health checks
- Support for dry-run validation to test configurations safely
- Bandwidth management and failover testing capabilities
- Alerts and notifications on replication status

#### Usage

To validate the configuration without making changes:

```powershell
.\replication_tasks.ps1 -ConfigFile .\replication_config.json -ValidateOnly
```

For actual execution:

```powershell
.\replication_tasks.ps1 -ConfigFile .\replication_config.json -Execute
```

## Error Handling

Both the Python and PowerShell scripts include extensive error handling to ensure reliability:

```python
try:
    # Core operation
except PowerStoreException as e:
    logging.error(f"PowerStore error: {e.message}")
    if e.error_code in RETRYABLE_ERRORS:
        retry_operation()
except Exception as e:
    logging.error(f"Unexpected error: {str(e)}")
```

```powershell
try {
    # Core operation
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

Contributions are highly encouraged! To contribute:

1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Commit your changes with clear, descriptive messages
4. Push your branch and open a Pull Request
5. Ensure your changes are accompanied by documentation updates and, if possible, test cases

## License

This repository is licensed under the MIT License. See the LICENSE file for full details.

---

*Report Bug · Request Feature*
