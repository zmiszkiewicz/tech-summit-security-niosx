#!/usr/bin/env python3
"""
Creates 2 NIOS-X join tokens via the Infoblox CSP API and exports them
as Terraform variables (TF_VAR_infoblox_join_token_1, TF_VAR_infoblox_join_token_2).
"""

import os
import json
import requests
import time
import sys

# --- Configuration ---
BASE_URL = "https://csp.infoblox.com"
JWT_FILE = "jwt.txt"
BASHRC_PATH = os.path.expanduser("~/.bashrc")

TOKEN_NAMES = ["demo-token-1", "demo-token-2"]
TF_VAR_NAMES = ["TF_VAR_infoblox_join_token_1", "TF_VAR_infoblox_join_token_2"]


def read_jwt():
    """Read JWT from file (created by deploy_api_key.py)."""
    try:
        with open(JWT_FILE, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        print(f"ERROR: {JWT_FILE} not found. Run deploy_api_key.py first.")
        sys.exit(1)


def create_join_token(jwt: str, token_name: str) -> str:
    """Create a single join token via the CSP API."""
    url = f"{BASE_URL}/atlas-host-activation/v1/jointoken"
    headers = {
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    payload = {
        "name": token_name,
        "description": f"Instruqt lab join token: {token_name}",
        "tags": {"instruqt": "tech-summit-security"}
    }

    print(f"Creating join token '{token_name}'...")
    response = requests.post(url, headers=headers, json=payload)
    response.raise_for_status()

    result = response.json().get("result", {})
    join_token = result.get("join_token")

    if not join_token:
        print(f"ERROR: Could not extract join_token from response for '{token_name}'")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        sys.exit(1)

    print(f"Join token '{token_name}' created successfully.")
    return join_token


def export_to_bashrc(var_name: str, value: str):
    """Append an export line to ~/.bashrc if not already present."""
    export_line = f'export {var_name}="{value}"\n'

    with open(BASHRC_PATH, "r") as f:
        content = f.read()

    # Remove any existing line for this variable
    lines = content.split("\n")
    lines = [l for l in lines if not l.strip().startswith(f"export {var_name}=")]
    content = "\n".join(lines)

    with open(BASHRC_PATH, "w") as f:
        f.write(content)
        if not content.endswith("\n"):
            f.write("\n")
        f.write(f"# Exported by infoblox_create_join_token.py on {time.ctime()}\n")
        f.write(export_line)

    # Also set in current process environment
    os.environ[var_name] = value
    print(f"Exported {var_name} to ~/.bashrc")


def main():
    jwt = read_jwt()

    for i, (token_name, tf_var) in enumerate(zip(TOKEN_NAMES, TF_VAR_NAMES)):
        join_token = create_join_token(jwt, token_name)
        export_to_bashrc(tf_var, join_token)

        # Brief pause between API calls
        if i < len(TOKEN_NAMES) - 1:
            time.sleep(5)

    print("Both join tokens created and exported successfully.")


if __name__ == "__main__":
    main()
