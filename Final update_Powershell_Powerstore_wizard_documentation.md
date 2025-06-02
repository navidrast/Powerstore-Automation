# PowerStore Automation Wizard v2.0 - User Guide

## Overview

The PowerStore Automation Wizard is a comprehensive PowerShell solution that combines LUN provisioning and reporting into a single, user-friendly interface. It features:

- **Interactive Setup Wizard**: Guides you through configuration and CSV file creation
- **Progress Tracking**: Visual progress bars and step-by-step status updates
- **Comprehensive Validation**: Pre-provisioning checks to prevent errors
- **HTML Reporting**: Beautiful, detailed reports with statistics and charts
- **Error Handling**: Robust error handling with detailed logging

## Quick Start

### Prerequisites

- **PowerShell**: 5.1 or higher
- **Network Access**: HTTPS connectivity to PowerStore management interface
- **Permissions**: PowerStore user account with provisioning rights

### Step 1: Download and Prepare

1. Download `PowerStore-Automation-Wizard.ps1`
2. Place it in your working directory
3. Open PowerShell as Administrator (Windows) or with appropriate permissions

### Step 2: Set Execution Policy (Windows)

```powershell
# Allow local scripts to run
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3: Run the Wizard

```powershell
# Interactive mode (recommended for first use)
.\PowerStore-Automation-Wizard.ps1

# Silent mode (using existing configuration)
.\PowerStore-Automation-Wizard.ps1 -Silent -ConfigFile "config.json" -InputCSV "luns.csv"
```

## Wizard Process Flow

### Step 1: Initialisation
- Checks PowerShell version
- Sets up logging
- Displays welcome screen

### Step 2: Configuration Setup
The wizard will:
- Check for existing `config.json`
- If not found, start interactive setup:
  - Request PowerStore management IP
  - Test connectivity
  - Request username and password
  - Configure SSL settings
  - Save configuration for future use

### Step 3: PowerStore Connection
- Connects to PowerStore using saved credentials
- Retrieves array information
- Establishes API session

### Step 4: Resource Discovery
- Discovers storage pools
- Enumerates existing hosts
- Maps current volume inventory

### Step 5: CSV File Handling
The wizard will:
- Look for default `luns.csv` file
- If not found, offer options:
  - Create sample CSV template
  - Specify existing CSV file path
- Open CSV for editing (Windows)

### Step 6: Pre-provisioning Validation
Comprehensive checks including:
- Required field validation
- Storage pool existence
- Host name verification
- Duplicate LUN name detection
- Capacity planning warnings
- Size validation

### Step 7: LUN Provisioning
- Creates LUNs based on CSV specifications
- Shows real-time progress with progress bars
- Tracks timing for performance metrics

### Step 8: Host Mapping
- Automatically maps LUNs to specified hosts
- Handles multiple hosts per LUN
- Reports mapping successes and failures

### Step 9: Post-provisioning Validation
- Verifies LUN creation
- Confirms host mappings
- Updates inventory

### Step 10: Report Generation
- Creates comprehensive HTML report
- Includes provisioning statistics
- Shows validation results
- Displays storage pool status
- Lists host information
- Automatically opens report (optional)

## CSV File Format

### Required Columns

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `Name` | String | ✓ | Unique LUN name | `prod_web_lun_01` |
| `Size_GB` | Number | ✓ | LUN size in GB | `1024` |
| `Pool` | String | ✓ | Storage pool name | `Pool0` |

### Optional Columns

| Column | Type | Required | Description | Example |
|--------|------|----------|-------------|---------|
| `Description` | String |  | LUN description | `Production web server storage` |
| `Host_Names` | String |  | Semicolon-separated host names | `host1;host2;host3` |
| `Thin_Provisioned` | String |  | Yes/No for thin provisioning | `Yes` |
| `Priority` | String |  | Business priority level | `High`, `Medium`, `Low`, `Critical` |

### Example CSV Content

```csv
Name
