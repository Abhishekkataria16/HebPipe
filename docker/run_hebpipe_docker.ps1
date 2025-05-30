# PowerShell script to build and run the HebPipe Docker container (CPU or GPU)

# Prompt user for CPU or GPU build
Write-Host "Choose Docker build type:"
Write-Host "1) CPU"
Write-Host "2) GPU"
$choice = Read-Host "Enter choice (1 or 2)"

# Define compose file based on choice
$composeFile = ""
$buildType = ""
if ($choice -eq "1") {
    $composeFile = "docker-compose-cpu.yml"
    $buildType = "cpu"
    Write-Host "Selected CPU build."
} elseif ($choice -eq "2") {
    $composeFile = "docker-compose-gpu.yml"
    $buildType = "gpu"
    Write-Host "Selected GPU build."
} else {
    Write-Host "Invalid choice. Exiting."
    exit 1
}

# Check if the selected compose file exists
if (-not (Test-Path $composeFile)) {
    Write-Host "Error: $composeFile not found."
    Write-Host "Please make sure 'docker-compose-cpu.yml' and 'docker-compose-gpu.yml' are in the current directory."
    exit 1
}

# Create a temporary copy of the compose file
$tempComposeFile = "$composeFile.tmp"
Copy-Item -Path $composeFile -Destination $tempComposeFile

# --- Volume Mounting Prompt ---
# Remove existing .env file if it exists
$envFile = ".env"
if (Test-Path $envFile) {
    Write-Host "Removing existing '$envFile' file."
    Remove-Item $envFile -Force
}

$mountVolume = "n"
$mountChoice = Read-Host "Do you want to mount a local directory for input/output? (y/n)"
if ($mountChoice -eq "y") {
    $mountVolume = "y"
    $localMountPath = Read-Host "Enter the local directory path to mount (e.g., ./input_data, default: ./input_data)"
    if ([string]::IsNullOrWhiteSpace($localMountPath)) {
        $localMountPath = ".\input_data"
    }
    $containerMountPath = Read-Host "Enter the container directory path (e.g., /app/input_data, default: /app/input_data)"
    if ([string]::IsNullOrWhiteSpace($containerMountPath)) {
        $containerMountPath = "/app/input_data"
    }

    # Ensure local mount path exists
    if (-not (Test-Path $localMountPath)) {
        Write-Host "Local mount path '$localMountPath' does not exist. Creating it."
        New-Item -Path $localMountPath -ItemType Directory -Force | Out-Null
    }

    # Create .env file with volume paths
    Write-Host "Creating .env file with volume configuration..."
    "LOCAL_INPUT_DIR=$localMountPath" | Out-File -Path $envFile -Encoding utf8
    "CONTAINER_INPUT_DIR=$containerMountPath" | Out-File -Path $envFile -Encoding utf8 -Append
} else {
    # If no volume mounting, comment out the volumes section in the temporary compose file
    $content = Get-Content $tempComposeFile
    $inVolumeSection = $false
    $newContent = @()
    
    foreach ($line in $content) {
        if ($line -match '^\s*volumes:') {
            $inVolumeSection = $true
            $newContent += "    # $line"
        } elseif ($inVolumeSection -and $line -match '^\s*-') {
            $newContent += "    # $line"
        } elseif ($inVolumeSection -and $line -match '^\S') {
            $inVolumeSection = $false
            $newContent += $line
        } elseif ($inVolumeSection) {
            $newContent += "    # $line"
        } else {
            $newContent += $line
        }
    }
    
    $newContent | Set-Content $tempComposeFile
}

Write-Host "Building and running HebPipe Docker container ($buildType)..."

# Set the environment variable for the Dockerfile build context
$env:HEBPIPE_INSTALL_TYPE = $buildType

# Execute docker compose with the temporary file
$process = Start-Process -FilePath "docker" -ArgumentList "compose", "-f", $tempComposeFile, "up", "-d" -Wait -PassThru
$dockerComposeExitCode = $process.ExitCode

# Clean up temporary file and environment variable
Remove-Item $tempComposeFile -Force
Remove-Item Env:\HEBPIPE_INSTALL_TYPE

if ($dockerComposeExitCode -ne 0) {
    Write-Host "Error: Docker Compose failed to build or run the container." -ForegroundColor Red
    exit $dockerComposeExitCode
}

Write-Host "HebPipe Docker container ($buildType) is running in detached mode." -ForegroundColor Green
Write-Host "To run HebPipe commands inside the container, use:" -ForegroundColor Cyan
Write-Host "docker compose -f $($composeFile) exec hebpipe [your heb_pipe command and arguments]" -ForegroundColor Yellow
if ($mountVolume -eq "y") {
    Write-Host "Note: Your local directory '$localMountPath' is mounted to '$containerMountPath' in the container." -ForegroundColor Cyan
    Write-Host "When processing files, use paths relative to '$containerMountPath' inside the container." -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Example: To process example_in.txt:" -ForegroundColor Cyan
# Provide example based on whether a volume was mounted
if ($mountVolume -eq "y") {
    Write-Host "docker compose -f $($composeFile) exec hebpipe `"$($containerMountPath)/example_in.txt`"" -ForegroundColor Yellow
} else {
    Write-Host "docker compose -f $($composeFile) exec hebpipe example_in.txt" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "To stop the container:" -ForegroundColor Cyan
Write-Host "docker compose -f $($composeFile) down" -ForegroundColor Yellow 