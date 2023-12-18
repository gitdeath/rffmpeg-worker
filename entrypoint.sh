#!/bin/bash
#sleeps to ensure healtcheck timeout didn't occur
sleep 21

# Add transcodessh user to the group that owns renderD128
# This is required, because unlike video the render group is different on each machine
renderD128_gid=$(stat -c "%g" /dev/dri/renderD128)
groupadd --gid "$renderD128_gid" render
usermod -a -G video transcodessh

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
