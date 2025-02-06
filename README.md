# PowerStore Automation Scripts Repository

<div align="center">

![PowerStore](https://img.shields.io/badge/Dell-PowerStore-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Python](https://img.shields.io/badge/Python-3.x-yellow)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)

</div>

This repository contains a collection of scripts to manage and automate tasks on Dell PowerStore arrays. Each script is designed to address a specific use case, such as creating file systems, managing NAS servers, and handling replication.

## Index of Scripts

| Script Name | Description | Language | Link to Instructions |
|------------|-------------|-----------|---------------------|
| `create_file_systems.py` | Automates file system creation using REST API | Python | [Instructions](#create_file_systemspy) |
| `create_file_systems.ps1` | Automates file system creation using PowerShell | PowerShell | [Instructions](#create_file_systemsps1) |
| `manage_nas_servers.py` | Manages NAS servers (create, update, delete) | Python | [Instructions](#manage_nas_serverspy) |
| `replication_tasks.ps1` | Configures replication tasks for file systems | PowerShell | [Instructions](#replication_tasksps1) |

## General Prerequisites

### PowerStore Requirements:
- Dell PowerStore array with REST API access
- Management IP address of the PowerStore array
- A user account with API permissions

### Host Requirements:
- Windows Jump Host with:
  - Python (3.x) installed, or
  - PowerShell (v5.1 or later)
- Internet access for installing dependencies (Python)

### CSV File Requirements:
Most scripts read configurations from a CSV file. Ensure the file format matches the requirements specified in the instructions for each script.

## Script Instructions

### create_file_systems.py

#### Description
Automates the creation of file systems on PowerStore arrays by reading configurations from a CSV file.

#### Prerequisites
- Python 3.x installed
- Dependencies installed via pip
- CSV file named `file_systems.csv` with the following structure:

```csv
NAS_Name,NAS_IP,FileSystemName,Size,Quota,Protocol
NAS1,192.168.1.10,FileSystem1,107374182400,,nfs
NAS2,192.168.1.11,FileSystem2,53687091200,1000000000,smb
```

#### Steps to Run

1. Clone this repository:
```bash
git clone https://github.com/<your-repo>/powerstore_automation.git
cd powerstore_automation
```

2. Update `powerstore_service.py` with your PowerStore credentials and management IP.

3. Execute the script:
```bash
python create_file_systems.py
```

### create_file_systems.ps1

#### Description
Automates the creation of file systems using PowerShell and the REST API.

#### Prerequisites
- PowerShell v5.1 or later
- CSV file named `file_systems.csv` (same structure as above)

#### Steps to Run

1. Clone this repository:
```bash
git clone https://github.com/<your-repo>/powerstore_automation.git
cd powerstore_automation
```

2. Execute the script:
```bash
.\create_file_systems.ps1
```

### manage_nas_servers.py

#### Description
Provides automation for managing NAS servers, including creation, updating, and deletion.

#### Prerequisites
- Python 3.x installed
- Dependencies installed via pip:
```bash
pip install -r requirements.txt
```
- CSV file containing NAS server details

#### Steps to Run

1. Update `manage_nas_servers.py` with your PowerStore credentials and management IP.

2. Execute the script:
```bash
python manage_nas_servers.py
```

### replication_tasks.ps1

#### Description
Configures and manages replication tasks for file systems.

#### Prerequisites
- PowerShell v5.1 or later
- Configuration file with replication task details

#### Steps to Run

1. Update `replication_tasks.ps1` with your PowerStore credentials and task details.

2. Execute the script:
```bash
.\replication_tasks.ps1
```

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve the scripts or add new use cases.

## License

This repository is licensed under the MIT License. See the [LICENSE](./LICENSE) file for more details.

---
<div align="center">
Made with ❤️ for PowerStore automation
</div>
