FROM debian:bookworm

RUN apt-get update && \
    apt-get -y install --no-install-recommends curl gnupg locales openssh-server nfs-common netbase iputils-ping fontconfig intel-opencl-icd && \
    # Set the locale
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    # Add jellyfin repo
    curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg && \
    echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" >> /etc/apt/sources.list.d/jellyfin.list && \
    # Install jellyfin-ffmpeg7 from the new repo and clean up
    apt-get update && \
    apt-get install -y --no-install-recommends jellyfin-ffmpeg7 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8  
ENV LANGUAGE=en_US:en  
ENV LC_ALL=en_US.UTF-8

# Create directories, set permissions, and configure fstab in a single layer
RUN mkdir -p /transcodes /cache /config /livetv && \
    chgrp users /transcodes /cache /config /livetv && \
    { \
      echo 'jellyfin-nfs-server:/transcodes /transcodes nfs rw,nolock,actimeo=1 0 0'; \
      echo 'jellyfin-nfs-server:/cache /cache nfs rw,nolock,actimeo=1 0 0'; \
    } > /etc/fstab

# create transcodessh user with proper perms
RUN useradd -u 7001 -g users -m transcodessh && \
    usermod --shell /bin/bash transcodessh && \    
    usermod -aG video,users transcodessh

#set umask to enable tmp file creation with write for users group
RUN echo 'umask 002' >> /etc/profile

# ensure nfs-server is reachable without a mounted /transcodes directory this worker can't do it's job
HEALTHCHECK --interval=5s --timeout=20s CMD ping -c 1 jellyfin-nfs-server

EXPOSE 22

# entrypoint runs mount -a to mount fstab entry above after container is started
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
