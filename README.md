# Jellyfin Remote Transcoding Worker

This Docker container is designed to act as a scalable, remote worker for a Jellyfin media server. Its sole purpose is to handle CPU and GPU-intensive video transcoding tasks, offloading them from the main Jellyfin instance.

It is built to be resilient, with health checks that monitor its connection to network storage and trigger a restart if the connection is lost, preventing it from becoming a "lame duck" worker.

## Features

*   **Dedicated Transcoder**: Isolates transcoding workloads from your main Jellyfin server.
*   **Scalable**: You can run multiple instances of this worker to handle a heavy transcoding load.
*   **Intel QSV Acceleration**: Supports Intel Quick Sync Video for hardware-accelerated transcoding via OpenCL (`intel-opencl-icd`).
*   **NFS Integration**: Automatically mounts `/transcodes` and `/cache` directories from an NFS server (`jellyfin-nfs-server`).
*   **Resilient Health Checking**: The entrypoint script constantly monitors the NFS connection. If the connection hangs for a few consecutive checks, the container will stop accepting new jobs and exit, allowing a container orchestrator (like Docker Compose or Kubernetes) to restart it.
*   **Automatic Updates**: A background process checks for and applies updates to `jellyfin-ffmpeg7` every 25 hours, ensuring you have the latest version without manual intervention (it will only update when no transcode is active).

## How It Works

1.  **Build**: The `Dockerfile` creates a Debian-based image containing `jellyfin-ffmpeg7`, an SSH server, and tools for NFS and Intel GPU access.
2.  **Initialization**: On startup, the `entrypoint.sh` script:
    *   Maps the host's GPU device (`/dev/dri/renderD128`) to the correct user permissions inside the container.
    *   Mounts the `/transcodes` and `/cache` directories from the NFS server specified in `/etc/fstab`.
    *   Starts the SSH daemon (`sshd`).
3.  **Connection**: The main Jellyfin server is configured to use this container as a "Remote Transcoder" by connecting to it via SSH with the `transcodessh` user.
4.  **Transcoding**: When a transcode is needed, Jellyfin executes an `ffmpeg` command on the worker via SSH. The worker uses its own CPU or GPU to perform the transcode, reading and writing files from the shared NFS volumes.
5.  **Monitoring**: The container continuously checks its own health. If the NFS share becomes unresponsive, the container gracefully shuts down to be replaced by a healthy instance.

## Configuration

*   **NFS Server**: The container is hardcoded to look for an NFS server with the hostname `jellyfin-nfs-server`. You must ensure this hostname is resolvable from the container's network.
*   **Shared Volumes**: Your NFS server must export `/transcodes` and `/cache` directories that are writable by the `users` group.
*   **GPU Passthrough**: To enable hardware acceleration, you must pass the host's render device to the container (e.g., by mapping `/dev/dri:/dev/dri`).
*   **User**: The container creates a `transcodessh` user with UID `7001` for Jellyfin to connect with.

## Verify Hardware Acceleration

You can test if the Intel OpenCL device is correctly detected and utilized within the container by running the following command:

```
/usr/lib/jellyfin-ffmpeg/ffmpeg -init_hw_device opencl=ocl -filter_hw_device ocl -f lavfi -i nullsrc=s=1920x1080,format=nv12 -vf hwupload,format=opencl -vframes 2000 -f null -
```
