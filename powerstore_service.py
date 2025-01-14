import requests
import csv
import json

# PowerStore configuration
BASE_URL = "https://<MGMT_IP_ADDRESS>/api/rest"
USERNAME = "<USERNAME>"
PASSWORD = "<PASSWORD>"
CSV_FILE = "file_systems.csv"

# Disable SSL warnings
requests.packages.urllib3.disable_warnings()

# Function to get NAS server ID by name
def get_nas_server_id(nas_name):
    url = f"{BASE_URL}/nas_servers"
    response = requests.get(url, auth=(USERNAME, PASSWORD), verify=False)
    if response.status_code == 200:
        nas_servers = response.json()
        for nas in nas_servers:
            if nas["name"] == nas_name:
                return nas["id"]
    else:
        print(f"Error fetching NAS servers: {response.text}")
        return None

# Function to create a file system
def create_file_system(nas_server_id, file_system_name, size, protocol, quota=None):
    url = f"{BASE_URL}/file_systems"
    payload = {
        "name": file_system_name,
        "nas_server_id": nas_server_id,
        "size_total": size,
        "default_access": protocol
    }
    if quota:
        payload["quota"] = quota

    headers = {"Content-Type": "application/json"}
    response = requests.post(
        url,
        auth=(USERNAME, PASSWORD),
        headers=headers,
        data=json.dumps(payload),
        verify=False
    )
    if response.status_code == 201:
        print(f"File system '{file_system_name}' created successfully.")
    else:
        print(f"Failed to create file system '{file_system_name}': {response.text}")

# Main function to read CSV and create file systems
def main():
    with open(CSV_FILE, mode="r") as file:
        reader = csv.DictReader(file)
        for row in reader:
            nas_name = row["NAS_Name"]
            file_system_name = row["FileSystemName"]
            size = int(row["Size"])
            protocol = row["Protocol"]
            quota = row["Quota"] if row["Quota"] else None

            print(f"Processing file system '{file_system_name}' for NAS '{nas_name}'...")
            nas_server_id = get_nas_server_id(nas_name)
            if nas_server_id:
                create_file_system(nas_server_id, file_system_name, size, protocol, quota)
            else:
                print(f"NAS server '{nas_name}' not found. Skipping.")

if __name__ == "__main__":
    main()