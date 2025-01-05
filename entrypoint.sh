#!/bin/bash

# Prevent files/subdirectories from being created that are unreachable by remote rffmpeg workers
umask 0002

# Sleep to ensure healthcheck timeout didn't occur
sleep 21

# Add transcodessh user to the group that owns renderD128
if [ -e /dev/dri/renderD128 ]; then
    renderD128_gid=$(stat -c "%g" /dev/dri/renderD128)
    groupadd --gid "$renderD128_gid" render
    usermod -a -G render transcodessh
    echo "transcodessh user was added to render group ($renderD128_gid)"
else
    echo "Warning: /dev/dri/renderD128 not found. Skipping GPU group setup."
fi

# Attempt to mount file systems from /etc/fstab
mount -a

if [ $? -eq 0 ]; then
    echo "Success: File systems mounted successfully."
else
    echo "Error: Failed to mount file systems. Exiting."
    exit 1
fi

# Trap SIGTERM and SIGINT signals to allow for graceful shutdown
trap "echo 'Shutting down...'; exit 0" SIGTERM SIGINT

# Start the sshd service and capture its PID
/usr/sbin/sshd -D &
sshd_pid=$!
# Repair SSHD, if unexpectedly terminated, or exit with error stopping the container.
if ! kill -0 $sshd_pid 2>/dev/null; then
    echo "Warning: SSHD process terminated unexpectedly. Attempting restart..."
    /usr/sbin/sshd -D &
    sshd_pid=$!
    if ! kill -0 $sshd_pid 2>/dev/null; then
        echo "Error: Failed to restart SSHD. Exiting."
        exit 1
    fi
fi


# Run df -h in a loop every 15 seconds - this stops the container if the NFS server share is no longer available (df -h would hang.) 
while true; do
  timeout 10 df -h > /dev/null 2>&1
  if [ $? -eq 124 ]; then
    echo "df -h command timed out. Terminating exiting container."
    exit 1
  fi
  sleep 15
done
