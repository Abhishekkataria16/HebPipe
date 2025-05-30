#!/bin/bash

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Check for Python 3
if command_exists python3;
then
    PYTHON_CMD="python3"
elif command_exists python;
then
    # Check if 'python' command is actually Python 3
    if python -c 'import sys; exit(not (sys.version_info.major == 3))'; then
        PYTHON_CMD="python"
    else
        echo "Error: 'python' command is not Python 3." >&2
        echo "Please install Python 3 and ensure it is in your system's PATH." >&2
        exit 1
    fi
else
    echo "Error: Python 3 not found in PATH." >&2
    echo "Please install Python 3 and ensure it is in your system's PATH." >&2
    exit 1
fi

# Check if venv module is available for Python 3
if ! "$PYTHON_CMD" -c "import venv" > /dev/null 2>&1; then
    echo "Error: Python 'venv' module not found." >&2
    echo "Please install the 'venv' module (e.g., 'sudo apt-get install python3-venv' on Debian/Ubuntu)." >&2
    exit 1
fi

# Prompt user for CPU or GPU installation
echo "Choose installation type:"
echo "1) CPU"
echo "2) GPU"
read -p "Enter choice (1 or 2): " choice

# Define requirements file based on choice
REQUIREMENTS_FILE=""
if [ "$choice" == "1" ]; then
    REQUIREMENTS_FILE="cpu-requirements.txt"
    echo "Selected CPU installation."
elif [ "$choice" == "2" ]; then
    REQUIREMENTS_FILE="gpu-requirements.txt"
    echo "Selected GPU installation."
else
    echo "Invalid choice. Exiting." >&2
    exit 1
fi

# Check if requirements file exists in the current directory
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "Error: $REQUIREMENTS_FILE not found in the current directory." >&2
    echo "Please make sure 'cpu-requirements.txt' and 'gpu-requirements.txt' are here." >&2
    exit 1
fi

# --- Virtual Environment Setup ---
VENV_DIR=".venv"
echo "Setting up virtual environment in '$VENV_DIR'..."

# Check if venv already exists
if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists. Skipping creation."
else
    # Create virtual environment
    if ! "$PYTHON_CMD" -m venv "$VENV_DIR"; then
        echo "Error creating virtual environment." >&2
        echo "Ensure the 'venv' module is available (e.g., 'sudo apt-get install python3-venv' on Debian/Ubuntu)." >&2
        exit 1
    fi
    echo "Virtual environment created successfully."
fi

# Define the path to the python executable inside the venv
VENV_PYTHON="$VENV_DIR/bin/python"

# Check if the venv python executable exists
if [ ! -f "$VENV_PYTHON" ]; then
    echo "Error: Could not find python executable in the virtual environment." >&2
    exit 1
fi

# --- Repository Cloning ---
REPO_DIR="HebPipe"
echo "Checking for '$REPO_DIR' repository..."

# Clone the repository if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning HebPipe repository..."
    if ! git clone https://github.com/amir-zeldes/HebPipe.git "$REPO_DIR"; then
        echo "Error: Failed to clone repository." >&2
        exit 1
    fi
    echo "Repository cloned successfully."
else
    echo "HebPipe repository already exists."
fi

# --- Installation within Venv ---
echo "Installing dependencies from $REQUIREMENTS_FILE using the virtual environment..."

# Install dependencies using pip from the virtual environment
if ! "$VENV_PYTHON" -m pip install --upgrade pip setuptools wheel; then
    echo "Warning: Failed to upgrade pip, setuptools, wheel." >&2
fi

if ! "$VENV_PYTHON" -m pip install -r "$REQUIREMENTS_FILE"; then
    echo "Error: Failed to install dependencies." >&2
    echo "Check the errors above for details on failed packages." >&2
    exit 1
fi
echo "Dependencies installed successfully."

# Install the HebPipe package using setup.py from within the cloned repository directory
echo "Running setup.py install from '$REPO_DIR' using the virtual environment..."

# We run setup.py from within the cloned repository directory
pushd "$REPO_DIR" > /dev/null || { echo "Error changing directory to $REPO_DIR." >&2; exit 1; }

if ! "$VENV_PYTHON" setup.py install; then
    echo "Warning: setup.py install failed. HebPipe might still be runnable via '$VENV_DIR/bin/python -m hebpipe' or similar." >&2
fi

popd > /dev/null || { echo "Error returning from directory $REPO_DIR." >&2; exit 1; }

echo "HebPipe installation script finished."
echo "To run HebPipe, activate the virtual environment first: 'source $VENV_DIR/bin/activate'."
echo "Then run 'python -m hebpipe [your arguments]'."
echo "Note: Model files are downloaded automatically by the script on first run or can be downloaded manually."
