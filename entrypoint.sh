#!/bin/bash

# Prevent files/subdirectories from being created that are unreachable by remote rffmpeg workers
umask 0002

# Function to print messages with timestamps
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Sleep to ensure healthcheck timeout didn't occur
sleep 21

# Add transcodessh user to the group that owns renderD128
if [ -e /dev/dri/renderD128 ]; then
    renderD128_gid=$(stat -c "%g" /dev/dri/renderD128)
    groupadd --gid "$renderD128_gid" render
    usermod -a -G render transcodessh
    log "transcodessh user was added to render group ($renderD128_gid)"
else
    log "Warning: /dev/dri/renderD128 not found. Skipping GPU group setup."
fi

# Attempt to mount file systems from /etc/fstab
mount -a

if [ $? -eq 0 ]; then
    log "Success: File systems mounted successfully."
else
    log "Error: Failed to mount file systems. Exiting."
    exit 1
fi

# Trap SIGTERM and SIGINT signals to allow for graceful shutdown
trap "log 'Shutting down...'; exit 0" SIGTERM SIGINT

# Start the sshd service and capture its PID
/usr/sbin/sshd -D &
sshd_pid=$!
# Repair SSHD, if unexpectedly terminated, or exit with error stopping the container.
if ! kill -0 $sshd_pid 2>/dev/null; then
    log "Warning: SSHD process terminated unexpectedly. Attempting restart..."
    /usr/sbin/sshd -D &
    sshd_pid=$!
    if ! kill -0 $sshd_pid 2>/dev/null; then
        log "Error: Failed to restart SSHD. Exiting."
        exit 1
    fi
fi

# Background process: Attempt to update jellyfin-ffmpeg7 every 25 hours
(
    while true; do
        if ! pgrep -x "ffmpeg" > /dev/null; then
            log "Checking for jellyfin-ffmpeg7 updates..."
            if apt list --upgradable 2>/dev/null | grep -q "^jellyfin-ffmpeg7/"; then
                log "Updating jellyfin-ffmpeg7..."
                apt update >/dev/null 2>&1 && apt install --only-upgrade jellyfin-ffmpeg7 -y >/dev/null 2>&1
                log "Update completed."
            fi
        else
            log "ffmpeg is running. Skipping update."
        fi
        sleep 90000  # Sleep for 25 hours (25 * 3600 seconds)
    done
) &

# Run df -h in a loop every 15 seconds - this stops the container if the NFS server share is no longer available (df -h would hang.) 
while true; do
  timeout 2 df -h > /dev/null 2>&1
  if [ $? -eq 124 ]; then
    log "df -h command timed out. Terminating container."
    exit 1
  fi
  sleep 15
done
