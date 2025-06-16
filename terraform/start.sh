#!/bin/bash
set -e
# Navigate to the app directory
cd /app

# Activate virtual environment
source venv/bin/activate

echo "=== Checking for FastAPI app object ==="
cd backend
# Try to start the server with more verbose output
echo "=== Attempting to start server with debug info ==="
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
python -c "
import sys
sys.path.insert(0, '.')
try:
    from main import app
    print('Successfully imported app from main')
    print(f'App object: {app}')
except Exception as e:
    print(f'Failed to import app: {e}')
    import traceback
    traceback.print_exc()
"

echo "=== Trying uvicorn with verbose logging ==="
python -m uvicorn main:app --host 0.0.0.0 --port 8080 --log-level debug --reload
