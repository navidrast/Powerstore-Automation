#!/usr/bin/env python3
import csv
import requests
import getpass
import urllib3

# Disable warnings for insecure connections (if needed)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def create_filesystem(ps_ip, username, password, filesystem):
    """
    Creates a filesystem on the PowerStore array via REST API.
    Adjust the URL and payload structure as required.
    """
    url = f"https://{ps_ip}/api/v1/filesystems"
    headers = {'Content-Type': 'application/json'}
    
    # Build the payload based on CSV values
    payload = {
        "NAS_Name": filesystem["NAS_Name"],
        "NAS_IP": filesystem["NAS_IP"],
        "FileSystemName": filesystem["FileSystemName"],
        "Size": int(filesystem["Size"]),
        "Protocol": filesystem["Protocol"]
    }
    # Add Quota only if provided
    if filesystem["Quota"].strip():
        payload["Quota"] = int(filesystem["Quota"])
    
    # Perform the POST request (verify=False used for self-signed certificates)
    response = requests.post(url, json=payload, auth=(username, password), headers=headers, verify=False)
    response.raise_for_status()  # Will raise an exception for HTTP errors
    return response.json()

def main():
    # Prompt for PowerStore connection details
    ps_ip = input("Enter PowerStore IP address: ")
    username = input("Enter username: ")
    password = getpass.getpass("Enter password: ")

    # Load CSV file with filesystem details
    csv_filename = "file_systems.csv"
    try:
        with open(csv_filename, newline='') as csvfile:
            fs_reader = csv.DictReader(csvfile)
            filesystems = list(fs_reader)
    except FileNotFoundError:
        print(f"Error: CSV file '{csv_filename}' not found.")
        return

    total = len(filesystems)
    print(f"Starting creation of {total} filesystems...")
    
    # Process each filesystem from CSV
    for index, fs in enumerate(filesystems, start=1):
        fs_name = fs["FileSystemName"]
        print(f"[{index}/{total}] Pending: Creating filesystem '{fs_name}'...")
        try:
            result = create_filesystem(ps_ip, username, password, fs)
            print(f"[{index}/{total}] Completed: Filesystem '{fs_name}' created. API response: {result}")
        except Exception as e:
            print(f"[{index}/{total}] Error: Could not create filesystem '{fs_name}': {e}")

if __name__ == "__main__":
    main()
