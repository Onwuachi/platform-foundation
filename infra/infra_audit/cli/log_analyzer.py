import json
import os

DATA_FILE = os.path.join("..", "data", "sample_ec2.json")

def load_data(file_path):
    with open(file_path, "r") as f:
        return json.load(f)

def analyze_ec2_instances(data):
    for inst in data.get("ec2_instances", []):
        status = "Public" if inst["public"] else "Private"
        print(f"Instance {inst['id']} is {status}")

if __name__ == "__main__":
    data = load_data(DATA_FILE)
    analyze_ec2_instances(data)
