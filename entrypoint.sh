#!/bin/bash
#sleeps to ensure healtcheck timeout didn't occur
sleep 21

# Attempt to mount file systems from /etc/fstab
mount -a

# Check the exit status of the mount command
if [ $? -eq 0 ]; then
    # Success CMD from Dockerfile (SSHD)
    echo "Success: File systems mounted successfully."
    exec "$@"
else
# Exits the container
    echo "Error: Failed to mount file systems. Exiting."
    exit 1
fi
