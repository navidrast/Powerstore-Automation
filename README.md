# PowerStore File System Creation Scripts

<div align="center">

![PowerStore](https://img.shields.io/badge/Dell-PowerStore-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10/11-blue?logo=windows)
![REST API](https://img.shields.io/badge/REST_API-v1-green)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/Status-Production-green)
![PowerStore Module](https://img.shields.io/badge/PowerStore_Module-Required-blue)

### Enterprise-grade automation scripts for Dell PowerStore file system management

[Overview](#overview) •
[Prerequisites](#prerequisites) •
[Installation](#installation) •
[Usage](#usage) •
[Documentation](#documentation) •
[Contributing](#contributing)

</div>

---

## Overview

This repository contains production-ready PowerShell scripts for automating file system creation on Dell PowerStore arrays. It offers two distinct approaches:

- **PowerShell Module Script** (`ps_fs_creation.ps1`): Utilises Dell's official PowerStore module
- **REST API Script** (`RESTAPI_fs_ps.ps1`): Direct REST API implementation for enhanced control

Both scripts provide robust error handling, detailed logging, and HTML report generation.

## Key Features

- 🚀 **Bulk Creation**: Efficiently process multiple file systems from CSV input
- 📊 **HTML Reporting**: Detailed execution reports with timestamps
- 🛡️ **Validation**: Comprehensive input validation and error handling
- 🔄 **Idempotency**: Safe to run multiple times with duplicate detection
- 📝 **Logging**: Detailed logging for troubleshooting
- 🔒 **Security**: Secure credential handling and certificate management

## Prerequisites

### System Requirements

| Component | Requirement |
|-----------|-------------|
| PowerShell | 5.1 or later |
| Windows | 10/11 or Server 2016+ |
| Memory | 4GB minimum |
| Network | Access to PowerStore array |

### PowerStore Requirements

- PowerStore OS version 2.0 or newer
- REST API access enabled
- Management IP configured
- Admin account with appropriate roles:
  - Storage Administrator
  - Storage Operator (minimum for read operations)

### Network Requirements

- HTTPS access (Port 443) to PowerStore array
- DNS resolution for management IP
- Proxy configuration (if required)

## Installation

1. **Clone Repository**
   ```powershell
   git clone https://github.com/yourusername/powerstore-scripts.git
   cd powerstore-scripts
   ```

2. **Install PowerStore Module**
   ```powershell
   Install-Module -Name Dell.PowerStore -Scope CurrentUser -Force
   ```

3. **Verify Installation**
   ```powershell
   Get-Module -ListAvailable Dell.PowerStore
   ```

## Usage

### Quick Start

1. **Prepare CSV File**
   Create `FileSystems.csv` with required columns.

   For PowerShell Module Script:
   ```csv
   FileSystemName,NAS_ServerName,CapacityGB,QuotaGB,Description,ConfigType,AccessPolicy
   prod_fs01,nas01,100,50,Production Data,GENERAL,UNIX
   ```

   For REST API Script:
   ```csv
   FileSystemName,Protocol,NAS_ServerName,CapacityGB,QuotaGB
   prod_fs01,nfs,nas01,100,50
   ```

2. **Run Script**
   ```powershell
   # Using PowerShell Module
   .\ps_fs_creation.ps1

   # Using REST API
   .\RESTAPI_fs_ps.ps1
   ```

### Advanced Options

#### PowerShell Module Script

```powershell
# Run with custom CSV path
.\ps_fs_creation.ps1 -CsvPath "C:\configs\custom_fs.csv"

# Enable verbose logging
.\ps_fs_creation.ps1 -Verbose
```

#### REST API Script

```powershell
# Run with custom API version
.\RESTAPI_fs_ps.ps1 -ApiVersion "v2"

# Enable debug mode
.\RESTAPI_fs_ps1 -Debug
```

## Documentation

### Script Comparison

| Feature | PowerShell Module | REST API |
|---------|------------------|-----------|
| Installation | Module required | No dependencies |
| Authentication | Module-handled | Token-based |
| Performance | Standard | Enhanced for bulk |
| Maintenance | Simpler | API knowledge needed |
| Error Handling | Built-in | Customisable |

### CSV Format Details

#### PowerShell Module Script

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| FileSystemName | Yes | Unique name | `prod_fs01` |
| NAS_ServerName | Yes | Target NAS | `nas01` |
| CapacityGB | Yes | Size in GB | `100` |
| QuotaGB | No | Quota limit | `50` |
| Description | No | Details | `Production Data` |
| ConfigType | No | Config type | `GENERAL` |
| AccessPolicy | No | Access rules | `UNIX` |

#### REST API Script

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| FileSystemName | Yes | Unique name | `prod_fs01` |
| Protocol | Yes | nfs/smb | `nfs` |
| NAS_ServerName | Yes | Target NAS | `nas01` |
| CapacityGB | Yes | Size in GB | `100` |
| QuotaGB | No | Quota limit | `50` |

### Security Best Practices

1. **Authentication**
   - Use token-based authentication
   - Implement token refresh
   - Never store credentials in scripts

2. **Certificate Handling**
   - Use proper certificate validation
   - Avoid global SSL bypasses
   - Implement selective certificate checks

3. **Error Management**
   - Implement retry mechanisms
   - Log all failures securely
   - Handle rate limiting

## Troubleshooting

### Common Issues

1. **Module Not Found**
   ```powershell
   Install-Module -Name Dell.PowerStore -Force
   ```

2. **Connection Failed**
   - Verify network connectivity
   - Check credentials
   - Confirm PowerStore management IP

3. **CSV Processing Errors**
   - Validate CSV format
   - Check for special characters
   - Ensure proper encoding (UTF-8)

### Logging

Both scripts generate detailed logs:
- HTML reports in script directory
- PowerShell transcript logs
- Error logs with timestamps

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

### Development Guidelines

- Follow PowerShell best practices
- Maintain consistent error handling
- Update documentation
- Add tests for new features

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Create an issue in the repository
- Contact the maintainer
- Review Dell PowerStore documentation

---

<div align="center">

**Made with ❤️ for PowerStore automation**

[Report Bug](../../issues) • [Request Feature](../../issues)

</div>
