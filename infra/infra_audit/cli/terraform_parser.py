import json
import os

DATA_FILE = os.path.join("..", "data", "sample_terraform_state.json")

def load_data(file_path):
    with open(file_path, "r") as f:
        return json.load(f)

def list_resources(data):
    resources = data["values"]["root_module"]["resources"]
    for res in resources:
        print(f"{res['type']}.{res['name']}  ->  {res['address']}")

if __name__ == "__main__":
    data = load_data(DATA_FILE)
    list_resources(data)
