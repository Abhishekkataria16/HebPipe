# HebPipe Docker Setup

This document explains how to build and run the HebPipe NLP pipeline using Docker.

## Prerequisites

*   Docker and Docker Compose installed on your system.
*   For GPU support: A compatible NVIDIA GPU and drivers installed.

## Setup

1.  **Clone the HebPipe repository:**
    ```bash
    git clone https://github.com/amir-zeldes/HebPipe.git
    cd HebPipe
    ```
    (If you haven't already, navigate to the repository root)

2.  **Navigate to the docker directory:**
    ```bash
    cd docker
    ```

3.  **Place Docker files:** Ensure the `Dockerfile.cpu`, `Dockerfile.gpu`, `docker-compose-cpu.yml`, `docker-compose-gpu.yml`, `run_hebpipe_docker.sh`, and `run_hebpipe_docker.ps1` scripts are in this directory.

## Building and Running the Docker Container

### Linux/macOS

Use the provided `run_hebpipe_docker.sh` script to build and run the Docker container. The script will:
*   Ask you to choose between a CPU and GPU build.
*   Ask if you want to mount a local directory for input/output. If yes, it will prompt for the local and container paths.
*   If you choose to mount a volume, the script will create or overwrite a `.env` file in the `docker` directory containing the `LOCAL_INPUT_DIR` and `CONTAINER_INPUT_DIR` environment variables.
*   Use the appropriate Docker Compose file (`docker-compose-cpu.yml` or `docker-compose-gpu.yml`).
*   Temporarily modify the selected compose file to include the volume mount if you chose that option.
*   Use `docker compose up -d` with the selected (and potentially modified) compose file to build the Docker image (if needed) and start the container in detached mode.

Make the script executable:
```bash
chmod +x run_hebpipe_docker.sh
```

Run the script from within the `docker` directory:
```bash
./run_hebpipe_docker.sh
```
Follow the prompts.

### Windows

Use the provided `run_hebpipe_docker.ps1` PowerShell script to build and run the Docker container. The script will:
*   Ask you to choose between a CPU and GPU build.
*   Ask if you want to mount a local directory for input/output. If yes, it will prompt for the local and container paths.
*   If you choose to mount a volume, the script will create or overwrite a `.env` file in the `docker` directory containing the `LOCAL_INPUT_DIR` and `CONTAINER_INPUT_DIR` environment variables.
*   Use the appropriate Docker Compose file (`docker-compose-cpu.yml` or `docker-compose-gpu.yml`).
*   Dynamically construct the `docker compose up -d --build` command, including the volume mount if you chose that option.

Run the script from within the `docker` directory in PowerShell:
```powershell
.\run_hebpipe_docker.ps1
```
Follow the prompts.

For both operating systems, the initial build might take some time, especially for the GPU version.

## Running HebPipe Commands

Once the container is running, you can execute HebPipe commands inside the container using `docker compose exec`. Since you will be running `docker compose` from within the `docker` directory, you do not need the `-f` flag when executing commands in the running container.

General format:
```bash
docker compose exec hebpipe [your heb_pipe command and arguments]
```

Example (if you mounted `./input_data` to `/app/input_data` during setup):
```bash
docker compose exec hebpipe /app/input_data/your_input_file.txt -o conllu
```
(Remember to redirect output to a local file on your host machine if needed: `> ../input_data/your_output.conllu`)

The `ENTRYPOINT` in the Dockerfiles is set to `python -m hebpipe`, so you can pass the standard HebPipe command-line arguments directly after `docker compose exec hebpipe`. The script will remind you of the container path if you mounted a volume.

### Processing a local file using a volume

When the build/run script prompts you, provide the local directory path you want to mount. The script will create or overwrite a `.env` file in the `docker` directory with the `LOCAL_INPUT_DIR` and `CONTAINER_INPUT_DIR` variables, which Docker Compose will automatically use.

Make sure to provide the *absolute* path to your local directory or a path *relative to the `docker` directory*.

### Stopping the container

When you are finished, you can stop the container using the `down` command from within the `docker` directory:

```bash
docker compose down
```

### Getting help

To see the HebPipe command-line help, you can run from within the `docker` directory:

```bash
docker compose exec hebpipe -h
```

## GPU Support Notes

*   Choosing the GPU build in the script requires `Dockerfile.gpu` and `docker-compose-gpu.yml` to be present in this directory.
*   You need a system with a compatible NVIDIA GPU and drivers installed.
*   The `Dockerfile.gpu` uses an NVIDIA CUDA runtime base image. Ensure this is compatible with your system and the PyTorch version in `gpu-requirements.txt`.
*   The `docker-compose-gpu.yml` file includes the necessary configuration (`deploy` section) to expose your GPU to the container.
