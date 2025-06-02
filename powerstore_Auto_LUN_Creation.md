# PowerStore Automation Scripts

Comprehensive Dell PowerStore LUN provisioning and reporting automation scripts that match your existing CSV export formats.

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

This automation suite provides two main scripts:

1. **`powerstore_lun_provision.py`** - Provisions LUNs based on CSV input and generates detailed reports
2. **`powerstore_report_generator.py`** - Generates comprehensive inventory reports matching your existing CSV exports

Both scripts use the official Dell PyPowerStore library and support your existing data formats.

## Prerequisites

### System Requirements
- **Python**: 3.8 or higher
- **Operating System**: Windows, Linux, or macOS
- **Network**: Connectivity to PowerStore management interface
- **Memory**: Minimum 512MB RAM
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

### Step 1: Install Python Dependencies

Open a command prompt or terminal and run:

```bash
# Install required Python packages
pip install PyPowerStore pandas configparser pathlib

# For development/testing (optional)
pip install pytest pytest-cov
```

### Step 2: Download Scripts

Download the following files to your working directory:
- `powerstore_lun_provision.py`
- `powerstore_report_generator.py`
- `README.md` (this file)

### Step 3: Verify Installation

Test the installation:

```bash
# Check Python version
python --version

# Verify package installation
python -c "import PyPowerStore, pandas; print('Installation successful')"
```

## Configuration

### Step 1: Create Configuration File

Generate a sample configuration file:

```bash
python powerstore_lun_provision.py --sample-config
```

This creates `config.ini` with the following structure:

```ini
[powerstore]
management_ip = 192.168.1.100
username = admin
password = your_password_here
verify_ssl = False

[logging]
level = INFO
log_file = powerstore_provision.log
```

### Step 2: Update Configuration

Edit `config.ini` with your PowerStore details:

1. **management_ip**: Your PowerStore management IP address
2. **username**: PowerStore username with provisioning permissions
3. **password**: PowerStore user password
4. **verify_ssl**: Set to `True` for production environments

### Step 3: Test Connection

Verify connectivity:

```bash
python powerstore_lun_provision.py -c config.ini --inventory
```

If successful, you'll see current LUN inventory displayed.

## Quick Start Guide

### 1. Generate Sample CSV Template

```bash
python powerstore_lun_provision.py --sample-csv
```

This creates `sample_luns.csv` with the correct format.

### 2. Edit CSV File

Open `sample_luns.csv` and modify according to your requirements:

```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
prod_app_lun_01,1024,Pool0,Production application data,apphost1;apphost2,Yes
dev_db_lun_01,512,Pool0,Development database,devhost1,Yes
```

### 3. Provision LUNs

```bash
python powerstore_lun_provision.py -c config.ini -i sample_luns.csv -o provision_report.csv
```

### 4. Review Results

Check the console output and `provision_report.csv` for detailed results.

## Detailed Usage Instructions

### LUN Provisioning Script

#### Basic Usage

```bash
python powerstore_lun_provision.py [OPTIONS]
```

#### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-c, --config` | Configuration file path (required) | `-c config.ini` |
| `-i, --input` | Input CSV file with LUN specifications | `-i luns_to_provision.csv` |
| `-o, --output` | Output CSV file for provision report | `-o provision_report.csv` |
| `--inventory` | Get current LUN inventory | `--inventory` |
| `--sample-csv` | Create sample CSV file | `--sample-csv` |
| `--sample-config` | Create sample config file | `--sample-config` |

#### Step-by-Step Provisioning Process

1. **Prepare Your Environment**
   ```bash
   # Create working directory
   mkdir powerstore_automation
   cd powerstore_automation
   
   # Generate configuration template
   python powerstore_lun_provision.py --sample-config
   ```

2. **Configure Connection**
   ```bash
   # Edit config.ini with your PowerStore details
   notepad config.ini  # Windows
   nano config.ini     # Linux/macOS
   ```

3. **Test Connectivity**
   ```bash
   # Verify connection and view current inventory
   python powerstore_lun_provision.py -c config.ini --inventory
   ```

4. **Create LUN Specification**
   ```bash
   # Generate sample CSV template
   python powerstore_lun_provision.py --sample-csv
   
   # Edit sample_luns.csv with your requirements
   notepad sample_luns.csv  # Windows
   nano sample_luns.csv     # Linux/macOS
   ```

5. **Validate Your CSV**
   Ensure your CSV includes:
   - Valid storage pool names (check with `--inventory`)
   - Existing host names (if specifying host attachments)
   - Unique LUN names
   - Appropriate sizes for available capacity

6. **Execute Provisioning**
   ```bash
   # Provision LUNs with detailed reporting
   python powerstore_lun_provision.py -c config.ini -i sample_luns.csv -o provision_report.csv
   ```

7. **Review Results**
   ```bash
   # Check console output for summary
   # Review provision_report.csv for detailed results
   # Check powerstore_provision.log for detailed logs
   ```

### Report Generator Script

#### Basic Usage

```bash
python powerstore_report_generator.py [OPTIONS]
```

#### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-c, --config` | Configuration file path (required) | `-c config.ini` |
| `-o, --output` | Output directory for reports | `-o reports` |
| `--all-reports` | Generate all report types | `--all-reports` |
| `--luns-only` | Generate LUNs report only | `--luns-only` |
| `--hosts-only` | Generate hosts report only | `--hosts-only` |
| `--pools-only` | Generate storage pools report only | `--pools-only` |
| `--filesystems-only` | Generate file systems report only | `--filesystems-only` |
| `--nfs-only` | Generate NFS shares report only | `--nfs-only` |

#### Step-by-Step Report Generation

1. **Generate All Reports**
   ```bash
   # Create comprehensive report suite
   python powerstore_report_generator.py -c config.ini --all-reports -o reports
   ```

2. **Generate Specific Reports**
   ```bash
   # LUNs only
   python powerstore_report_generator.py -c config.ini --luns-only
   
   # Storage pools only
   python powerstore_report_generator.py -c config.ini --pools-only
   
   # Hosts only
   python powerstore_report_generator.py -c config.ini --hosts-only
   ```

3. **Review Generated Reports**
   ```bash
   # Navigate to reports directory
   cd reports
   
   # List generated files
   ls -la  # Linux/macOS
   dir     # Windows
   ```

## CSV File Formats

### LUN Provisioning CSV Format

**File**: `luns_to_provision.csv`

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| Name | String | Yes | Unique LUN name | `prod_app_lun_01` |
| Size_GB | Float | Yes | LUN size in GB | `1024` |
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
3. **Valid Pool Names**: Pool names must exist (check with `--inventory`)
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
| name | LUN name from CSV |
| status | SUCCESS, FAILED, or VALIDATION_FAILED |
| message | Detailed status message |
| lun_id | PowerStore LUN ID (if successful) |
| wwn | LUN World Wide Name |
| size_gb | Requested size in GB |
| pool | Storage pool used |
| hosts_attached | Successfully attached hosts |
| timestamp | Provision attempt timestamp |

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

#### 1. Connection Issues

**Error**: `Failed to connect to PowerStore`

**Solutions**:
```bash
# Check network connectivity
ping 192.168.1.100

# Verify PowerStore management interface
curl -k https://192.168.1.100/swaggerui

# Test credentials manually
# (Try logging into PowerStore Manager web interface)
```

#### 2. Authentication Failures

**Error**: `Authentication failed`

**Solutions**:
- Verify username and password in `config.ini`
- Check if account is locked in PowerStore
- Ensure user has required permissions
- Try logging in via web interface to test credentials

#### 3. Permission Errors

**Error**: `Insufficient permissions`

**Solutions**:
- Contact PowerStore administrator
- Verify user role includes:
  - Storage Provisioning
  - Host Management
  - Configuration Management

#### 4. CSV Format Errors

**Error**: `Missing required field` or `Invalid CSV format`

**Solutions**:
```bash
# Generate new sample CSV
python powerstore_lun_provision.py --sample-csv

# Check CSV encoding (should be UTF-8)
file -I your_file.csv  # Linux/macOS

# Validate CSV structure
head -5 your_file.csv
```

#### 5. Storage Pool Issues

**Error**: `Storage pool 'PoolX' does not exist`

**Solutions**:
```bash
# List available pools
python powerstore_lun_provision.py -c config.ini --inventory

# Check pool names match exactly (case-sensitive)
# Update CSV with correct pool names
```

#### 6. Host Mapping Issues

**Error**: `Host 'hostname' does not exist`

**Solutions**:
```bash
# Generate hosts report
python powerstore_report_generator.py -c config.ini --hosts-only

# Check exact host names in PowerStore
# Update CSV with correct host names
# Leave Host_Names column empty if not mapping immediately
```

### Debug Mode

Enable detailed logging:

```bash
# Edit config.ini
[logging]
level = DEBUG
log_file = powerstore_provision.log

# Run with verbose output
python powerstore_lun_provision.py -c config.ini -i luns.csv -o report.csv 2>&1 | tee console.log
```

### Log File Analysis

Check `powerstore_provision.log` for detailed information:

```bash
# View recent log entries
tail -50 powerstore_provision.log

# Search for errors
grep -i error powerstore_provision.log

# Search for specific LUN
grep "lun_name" powerstore_provision.log
```

## Advanced Configuration

### Environment Variables

You can use environment variables instead of storing passwords in config files:

```bash
# Set environment variables
export POWERSTORE_PASSWORD="your_secure_password"
export POWERSTORE_USERNAME="admin"
export POWERSTORE_IP="192.168.1.100"
```

Update `config.ini`:
```ini
[powerstore]
management_ip = ${POWERSTORE_IP}
username = ${POWERSTORE_USERNAME}
password = ${POWERSTORE_PASSWORD}
verify_ssl = True
```

### Batch Processing

For large LUN deployments:

```bash
# Split large CSV into smaller batches
split -l 50 large_luns.csv batch_

# Process batches sequentially
for batch in batch_*; do
    echo "Processing $batch..."
    python powerstore_lun_provision.py -c config.ini -i "$batch" -o "report_$batch.csv"
    sleep 10  # Brief pause between batches
done
```

### Automated Scheduling

#### Windows (Task Scheduler)

1. Create batch file (`provision_luns.bat`):
```batch
@echo off
cd C:\powerstore_automation
python powerstore_lun_provision.py -c config.ini -i daily_luns.csv -o daily_report.csv
```

2. Schedule in Task Scheduler:
   - Action: Start a program
   - Program: `C:\powerstore_automation\provision_luns.bat`
   - Schedule: As required

#### Linux (Crontab)

```bash
# Edit crontab
crontab -e

# Add daily execution at 2 AM
0 2 * * * cd /opt/powerstore_automation && python powerstore_lun_provision.py -c config.ini -i daily_luns.csv -o daily_report.csv

# Add weekly reports on Sundays at 1 AM
0 1 * * 0 cd /opt/powerstore_automation && python powerstore_report_generator.py -c config.ini --all-reports -o weekly_reports
```

### Integration with ITSM

#### ServiceNow Integration

Create wrapper script for ServiceNow integration:

```python
#!/usr/bin/env python3
"""ServiceNow PowerStore Integration"""

import sys
import json
import subprocess

def provision_from_servicenow(ticket_data):
    """Process ServiceNow ticket data"""
    # Convert ServiceNow data to CSV
    # Call provisioning script
    # Return results to ServiceNow
    pass

if __name__ == "__main__":
    ticket_json = sys.argv[1]
    ticket_data = json.loads(ticket_json)
    result = provision_from_servicenow(ticket_data)
    print(json.dumps(result))
```

## Security Considerations

### User Account Security

1. **Create Dedicated Service Account**:
   ```
   Username: svc_automation
   Role: Storage_Provisioner (custom role)
   Description: PowerStore automation service account
   ```

2. **Minimum Required Permissions**:
   - Volume creation and modification
   - Host mapping and unmapping
   - Storage pool read access
   - File system read access

3. **Account Management**:
   - Regular password rotation (quarterly)
   - Monitor login attempts
   - Disable when not in use
   - Use strong passwords (12+ characters)

### Network Security

1. **SSL/TLS Configuration**:
   ```ini
   [powerstore]
   verify_ssl = True  # Always use in production
   ```

2. **Network Isolation**:
   - Run scripts from management network
   - Use VPN for remote access
   - Implement firewall rules

3. **Certificate Management**:
   ```bash
   # Download PowerStore certificate
   openssl s_client -connect powerstore.domain.com:443 -showcerts
   
   # Add to trusted certificates
   cp powerstore.crt /etc/ssl/certs/
   ```

### File Security

1. **Configuration File Protection**:
   ```bash
   # Set restrictive permissions
   chmod 600 config.ini
   chown user:user config.ini
   ```

2. **Log File Security**:
   ```bash
   # Secure log directory
   chmod 750 /var/log/powerstore/
   
   # Rotate logs regularly
   logrotate /etc/logrotate.d/powerstore
   ```

3. **CSV File Handling**:
   - Encrypt sensitive data in transit
   - Secure deletion after processing
   - Access logging for audit trails

## Examples

### Example 1: Simple LUN Provisioning

**Scenario**: Provision 3 LUNs for a new application

**Steps**:
1. Create CSV file (`app_luns.csv`):
```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
app_data_01,1024,Pool0,Application data volume,apphost1;apphost2,Yes
app_logs_01,256,Pool0,Application logs volume,apphost1;apphost2,Yes
app_temp_01,512,Pool0,Application temp volume,apphost1,Yes
```

2. Execute provisioning:
```bash
python powerstore_lun_provision.py -c config.ini -i app_luns.csv -o app_provision_report.csv
```

3. Review results:
```bash
cat app_provision_report.csv
```

### Example 2: Database Environment Setup

**Scenario**: Provision LUNs for production database cluster

**Steps**:
1. Create CSV file (`db_cluster_luns.csv`):
```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
prod_db_data_01,4096,Pool0,Primary database data,dbhost1,Yes
prod_db_data_02,4096,Pool0,Secondary database data,dbhost2,Yes
prod_db_logs_01,1024,Pool1,Database transaction logs,dbhost1;dbhost2,Yes
prod_db_backup_01,8192,Pool1,Database backup storage,,No
```

2. Validate storage capacity first:
```bash
python powerstore_lun_provision.py -c config.ini --inventory
```

3. Execute provisioning:
```bash
python powerstore_lun_provision.py -c config.ini -i db_cluster_luns.csv -o db_provision_report.csv
```

### Example 3: Monthly Capacity Reporting

**Scenario**: Generate monthly capacity reports for management

**Steps**:
1. Create automated script (`monthly_report.sh`):
```bash
#!/bin/bash
REPORT_DATE=$(date +%Y_%m)
REPORT_DIR="/reports/monthly/$REPORT_DATE"

mkdir -p "$REPORT_DIR"

python powerstore_report_generator.py \
    -c /opt/powerstore/config.ini \
    --all-reports \
    -o "$REPORT_DIR"

# Email reports to management
tar -czf "$REPORT_DIR.tar.gz" "$REPORT_DIR"
echo "Monthly PowerStore capacity report attached" | \
    mail -s "PowerStore Monthly Report - $REPORT_DATE" \
    -A "$REPORT_DIR.tar.gz" \
    management@company.com
```

2. Schedule in crontab:
```bash
# First day of each month at 6 AM
0 6 1 * * /opt/powerstore/monthly_report.sh
```

### Example 4: Development Environment Automation

**Scenario**: Automated dev environment provisioning

**Steps**:
1. Create template CSV (`dev_template.csv`):
```csv
Name,Size_GB,Pool,Description,Host_Names,Thin_Provisioned
dev_${ENV}_app_01,512,Pool0,Dev environment app data,${ENV}host1,Yes
dev_${ENV}_db_01,1024,Pool0,Dev environment database,${ENV}host1,Yes
```

2. Create environment provisioning script:
```python
#!/usr/bin/env python3
import sys
import pandas as pd
import subprocess

def create_dev_environment(env_name):
    # Read template
    df = pd.read_csv('dev_template.csv')
    
    # Replace placeholders
    df['Name'] = df['Name'].str.replace('${ENV}', env_name)
    df['Host_Names'] = df['Host_Names'].str.replace('${ENV}', env_name)
    df['Description'] = df['Description'].str.replace('${ENV}', env_name)
    
    # Save customised CSV
    output_file = f'dev_{env_name}_luns.csv'
    df.to_csv(output_file, index=False)
    
    # Provision LUNs
    cmd = [
        'python', 'powerstore_lun_provision.py',
        '-c', 'config.ini',
        '-i', output_file,
        '-o', f'dev_{env_name}_report.csv'
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0

if __name__ == "__main__":
    env_name = sys.argv[1]
    success = create_dev_environment(env_name)
    print(f"Environment {env_name} provisioning: {'SUCCESS' if success else 'FAILED'}")
```

3. Usage:
```bash
python create_dev_env.py test123
python create_dev_env.py staging456
```

---

## Support and Maintenance

### Regular Maintenance Tasks

1. **Weekly**: Review provision logs for errors
2. **Monthly**: Update capacity reports
3. **Quarterly**: Rotate service account passwords
4. **Annually**: Review and update security configurations

### Getting Help

1. **Check logs**: Always review `powerstore_provision.log` first
2. **Test connectivity**: Use `--inventory` to verify connection
3. **Validate CSV**: Use sample CSV as template
4. **Check permissions**: Verify PowerStore user permissions

### Contact Information

For script-related issues:
- Review this README thoroughly
- Check log files for detailed error messages
- Verify CSV format against samples
- Test with smaller datasets first

For PowerStore-specific issues:
- Consult Dell PowerStore documentation
- Contact Dell support for array issues
- Check Dell PowerStore community forums

---

**Last Updated**: June 2025  
**Version**: 1.0  
**Compatibility**: PowerStore OS 1.0+, Python 3.8+
