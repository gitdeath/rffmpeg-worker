#!/bin/bash
set -e

# Prevent files/subdirectories from being created that are unreachable by remote rffmpeg workers
umask 002

# Function to print messages with timestamps
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}
log "Starting rffmpeg-worker container..."

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
log "Success: File systems mounted successfully."

# Background process: Attempt to update jellyfin-ffmpeg7 every 25 hours
(
  set -e
  while true; do
    sleep 90000 # Sleep for 25 hours (25 * 3600 seconds)
    if ! pgrep -x "ffmpeg" >/dev/null; then
      log "Checking for jellyfin-ffmpeg7 updates..."
      if apt-get update >/dev/null 2>&1 && apt list --upgradable 2>/dev/null | grep -q "^jellyfin-ffmpeg7/"; then
        log "New version of jellyfin-ffmpeg7 found. Updating..."
        apt-get install --only-upgrade -y jellyfin-ffmpeg7 >/dev/null 2>&1
        log "jellyfin-ffmpeg7 update completed."
      fi
    else
      log "ffmpeg process is running. Skipping update check."
    fi
  done
) &

# Background process: Monitor NFS connection and shut down if it becomes unresponsive.
(
  FAIL_COUNT=0
  MAX_FAILS=3
  SLEEP_INTERVAL=3
  while true; do
    sleep $SLEEP_INTERVAL
    if timeout 2 df -h >/dev/null 2>&1; then
      if [ $FAIL_COUNT -gt 0 ]; then
        log "INFO: NFS connection recovered after $FAIL_COUNT failed attempts."
      fi
      FAIL_COUNT=0
    else
      ((FAIL_COUNT++))
      log "WARNING: 'df -h' timed out. Consecutive failures: $FAIL_COUNT/$MAX_FAILS"
      if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
        log "CRITICAL: NFS is unresponsive. Shutting down to prevent new jobs."
        # Kill the main sshd process to trigger a container exit.
        pkill -f /usr/sbin/sshd
        break
      fi
    fi
  done
) &

# Trap SIGTERM and SIGINT signals to allow for graceful shutdown
trap "log 'Received shutdown signal, stopping sshd...'; pkill -f /usr/sbin/sshd; wait; exit 0" SIGTERM SIGINT

log "Starting SSHD..."
# Start the sshd service in the foreground. It will be the main process.
# The -e flag sends logs to stderr, which is useful for container logging.
/usr/sbin/sshd -D -e &

# Wait for sshd to exit. This will happen if it's killed by the health check or an external signal.
wait $!
log "SSHD has stopped. Exiting container."
