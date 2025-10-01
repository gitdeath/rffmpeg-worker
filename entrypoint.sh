#!/bin/bash

# Prevent files/subdirectories from being created that are unreachable by remote rffmpeg workers
umask 002

# Function to print messages with timestamps
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}
log "Starting rffmpeg-worker container..."
# Sleep to ensure healthcheck timeout didn't occur
sleep 21

# Add transcodessh user to the group that owns renderD128
if [ -e /dev/dri/renderD128 ]; then
    renderD128_gid=$(stat -c "%g" /dev/dri/renderD128)
    groupadd --gid "$renderD128_gid" render
    usermod -aG render transcodessh
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

# Start the sshd service in the foreground. It will be the main process.
/usr/sbin/sshd -D &
sshd_pid=$!
log "SSHD started with PID $sshd_pid"

# Background process: Attempt to update jellyfin-ffmpeg7 every 25 hours
(
    while true; do
        if ! pgrep -x "ffmpeg" > /dev/null; then
            log "Checking for jellyfin-ffmpeg7 updates..."
            if apt list --upgradable 2>/dev/null | grep -q "^jellyfin-ffmpeg7/"; then
                log "New version of jellyfin-ffmpeg7 found. Updating..."
                apt-get update >/dev/null && apt-get install --only-upgrade -y jellyfin-ffmpeg7 >/dev/null
                log "jellyfin-ffmpeg7 update completed."
            fi
        else
            log "ffmpeg process is running. Skipping update check."
        fi
        sleep 90000  # Sleep for 25 hours (25 * 3600 seconds)
    done
) &

# Run df -h in a loop every 5 seconds - this stops the container if the NFS server share is no longer available (df -h would hang.) 
FAIL_COUNT=0
MAX_FAILS=3
SLEEP_INTERVAL=3

while true; do
  # Check if sshd is still running. If not, the container should exit.
  if ! kill -0 $sshd_pid 2>/dev/null; then
    log "CRITICAL: sshd process is not running. Terminating container."
    exit 1
  fi

  timeout 2 df -h > /dev/null 2>&1
  if [ $? -eq 124 ]; then
    ((FAIL_COUNT++))
    log "WARNING: 'df -h' timed out. Consecutive failures: $FAIL_COUNT/$MAX_FAILS"
    if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
      log "CRITICAL: NFS is unresponsive. Shutting down to prevent new jobs."
      # Stop the SSH daemon to refuse new connections.
      log "Stopping SSH daemon..."
      kill "$sshd_pid"
      # Exit the container. The orchestrator should restart it.
      exit 1
    fi
  else
    if [ $FAIL_COUNT -gt 0 ]; then
      log "INFO: NFS connection recovered after $FAIL_COUNT failed attempts."
    fi
    FAIL_COUNT=0
  fi
  sleep $SLEEP_INTERVAL
done
