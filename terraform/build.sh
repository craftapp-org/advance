#!/bin/bash
set -e

echo "=== Starting build process ==="

# Create and activate virtual environment
python3 -m venv /app/venv
source /app/venv/bin/activate

# Upgrade pip and install dependencies
pip3 install --upgrade pip
pip3 install fastapi uvicorn
pip3 install -r ./backend/requirements.txt

# Ensure start.sh is executable
# chmod +x ./start.sh

# List installed packages
pip3 list
