#!/bin/bash

# Prevent files/subdirectories from being created that are unreachable by remote rffmpeg workers
umask 0002

# Sleep to ensure healthcheck timeout didn't occur
sleep 21

# Add transcodessh user to the group that owns renderD128
renderD128_gid=$(stat -c "%g" /dev/dri/renderD128)
groupadd --gid "$renderD128_gid" render
usermod -a -G render transcodessh

# Attempt to mount file systems from /etc/fstab
mount -a

# Check the exit status of the mount command
if [ $? -eq 0 ]; then
    echo "Success: File systems mounted successfully."
else
    echo "Error: Failed to mount file systems. Exiting."
    exit 1
fi

# Start the sshd service and capture its PID
/usr/sbin/sshd -D &
sshd_pid=$!

# Run df -h in a loop every 15 seconds - this stops the container if the NFS server share is no longer available (df -h would hang.) 
while true; do
  timeout 5 df -h > /dev/null 2>&1
  if [ $? -eq 124 ]; then
    echo "df -h command timed out. Terminating sshd and exiting container."
    kill "$sshd_pid"
    wait "$sshd_pid"  # Wait for sshd to terminate
    exit 1
  fi
  sleep 15
done
