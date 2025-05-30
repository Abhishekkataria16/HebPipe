# PowerShell script to install HebPipe (CPU or GPU) with a virtual environment

# Function to check if Python 3 is installed and in PATH
function Test-Python3 {
    try {
        $py = Get-Command python3 -ErrorAction SilentlyContinue
        if ($py -ne $null) {
            Write-Host "Found python3: $($py.Source)"
            return $true
        }
        $py = Get-Command python -ErrorAction SilentlyContinue
        if ($py -ne $null) {
            # Check if 'python' command is actually Python 3
            $version_output = & $py.Source --version
            if ($version_output -match "Python 3\.\d+\.\d+") {
                 Write-Host "Found python (Python 3): $($py.Source)"
                 return $true
            }
        }
        Write-Host "Python 3 not found in PATH." -ForegroundColor Red
        return $false
    } catch {
        Write-Host "Error checking for Python 3: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check for Python 3
if (-not (Test-Python3)) {
    Write-Host "Please install Python 3 and ensure it is in your system's PATH." -ForegroundColor Yellow
    exit 1
}

# Prompt user for CPU or GPU installation
Write-Host "Choose installation type:"
Write-Host "1) CPU"
Write-Host "2) GPU"
$choice = Read-Host "Enter choice (1 or 2)"

# Define requirements file based on choice
$requirementsFile = ""
if ($choice -eq "1") {
    $requirementsFile = "cpu-requirements.txt"
    Write-Host "Selected CPU installation."
} elseif ($choice -eq "2") {
    $requirementsFile = "gpu-requirements.txt"
    Write-Host "Selected GPU installation."
} else {
    Write-Host "Invalid choice. Exiting."
    exit 1
}

# Check if requirements file exists in the current directory
if (-not (Test-Path $requirementsFile)) {
    Write-Host "Error: $requirementsFile not found in the current directory." -ForegroundColor Red
    Write-Host "Please make sure 'cpu-requirements.txt' and 'gpu-requirements.txt' are here." -ForegroundColor Yellow
    exit 1
}

# --- Virtual Environment Setup ---
$venvDir = ".venv"
Write-Host "Setting up virtual environment in '$venvDir'..."

# Check if venv already exists
if (Test-Path $venvDir) {
    Write-Host "Virtual environment already exists. Skipping creation." -ForegroundColor Yellow
} else {
    # Create virtual environment
    try {
        & python -m venv $venvDir
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error creating virtual environment. Ensure the 'venv' module is available." -ForegroundColor Red
            exit 1
        }
        Write-Host "Virtual environment created successfully."
    } catch {
        Write-Host "Error creating virtual environment: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Ensure the 'venv' module is available." -ForegroundColor Yellow
        exit 1
    }
}

# Define the path to the python executable inside the venv
$venvPython = Join-Path $venvDir "Scripts\python.exe"

# Check if the venv python executable exists
if (-not (Test-Path $venvPython)) {
    Write-Host "Error: Could not find python executable in the virtual environment." -ForegroundColor Red
    exit 1
}

Write-Host "Found venv python at $venvPython."

# --- Repository Cloning ---
$repoDir = "HebPipe"
Write-Host "Checking for '$repoDir' repository..."

# Clone the repository if it doesn't exist
if (-not (Test-Path $repoDir -PathType Container)) {
    Write-Host "Cloning HebPipe repository..."
    try {
        & git clone https://github.com/amir-zeldes/HebPipe.git $repoDir
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to clone repository." -ForegroundColor Red
            exit 1
        }
        Write-Host "Repository cloned successfully."
    } catch {
        Write-Host "Error cloning repository: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "HebPipe repository already exists."
}

# --- Installation within Venv ---
Write-Host "Installing dependencies from $requirementsFile using the virtual environment..."

# Install dependencies using pip from the virtual environment
try {
    & $venvPython -m pip install --upgrade pip setuptools wheel
    if ($LASTEXITCODE -ne 0) { Write-Host "Warning: Failed to upgrade pip, setuptools, wheel." -ForegroundColor Yellow }
    & $venvPython -m pip install -r "$requirementsFile"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to install dependencies." -ForegroundColor Red
        Write-Host "Check the errors above for details on failed packages." -ForegroundColor Red
        exit 1
    }
    Write-Host "Dependencies installed successfully."
} catch {
    Write-Host "Error installing dependencies: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Install the HebPipe package using setup.py from within the cloned repository directory
Write-Host "Running setup.py install from '$repoDir' using the virtual environment..."

try {
    # Change directory, run command, then change back
    Push-Location $repoDir
    & $venvPython setup.py install
    $setupExitCode = $LASTEXITCODE
    Pop-Location

    if ($setupExitCode -ne 0) {
        Write-Host "Warning: setup.py install failed ($setupExitCode). HebPipe might still be runnable via '.\$venvDir\Scripts\python.exe -m hebpipe' or similar." -ForegroundColor Yellow
    } else {
        Write-Host "setup.py install completed."
    }
} catch {
    Write-Host "Error running setup.py install: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "HebPipe might still be runnable via '.\$venvDir\Scripts\python.exe -m hebpipe' or similar." -ForegroundColor Yellow
}

Write-Host "HebPipe installation script finished."
Write-Host "To run HebPipe, activate the virtual environment first: '.\$venvDir\Scripts\Activate.ps1'."
Write-Host "Then run 'python -m hebpipe [your arguments]'."
Write-Host "Note: Model files are downloaded automatically by the script on first run or can be downloaded manually." 