#!/bin/bash
set -e

# Activate the virtual environment
source /app/venv/bin/activate

# Upgrade pip and install dependencies
pip3 install --upgrade pip
pip3 install fastapi uvicorn
pip3 install -r ./backend/requirements.txt

# Start the application
uvicorn backend.main:app --host 0.0.0.0 --port 8080
