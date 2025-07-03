FROM debian:bookworm
# install requirements for adding jellyfin repo

RUN apt update && \
    apt -y install curl gnupg locales

    # Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8  
ENV LANGUAGE=en_US:en  
ENV LC_ALL=en_US.UTF-8 

# add jellyfin repo
RUN curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg
RUN echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" >> /etc/apt/sources.list.d/jellyfin.list
# install requirements to perform transcoding, including OpenCL intel-opencl-icd
RUN apt update && \
    apt install -y openssh-server nfs-common netbase jellyfin-ffmpeg7 iputils-ping fontconfig && \
    apt install -y intel-opencl-icd



# Make and set perms /transcodes, /config, /livetv, and /cache
RUN mkdir -p /transcodes && \
    chgrp users /transcodes
RUN mkdir -p /cache && \
    chgrp users /cache
RUN mkdir -p /config && \
    chgrp users /config
RUN mkdir -p /livetv && \
    chgrp users /livetv

# setup fstab for mount to nfs-server
RUN echo 'jellyfin-nfs-server:/transcodes /transcodes nfs rw,nolock,actimeo=1 0 0' > /etc/fstab
RUN echo 'jellyfin-nfs-server:/cache /cache nfs rw,nolock,actimeo=1 0 0' >> /etc/fstab

# create transcodessh user with proper perms
RUN useradd -u 7001 -g users -m transcodessh && \
    #groupadd -g 106 render && \
    usermod --shell /bin/bash transcodessh && \
    chown -R transcodessh /usr/lib/jellyfin-ffmpeg && \
    usermod -a -G video,users transcodessh

#set umask to enable tmp file creation with write for users group
RUN echo 'umask 002' >> /etc/profile

RUN service ssh start

# ensure nfs-server is reachable without a mounted /transcodes directory this worker can't do it's job
HEALTHCHECK --interval=5s --timeout=20s CMD ping -c 1 jellyfin-nfs-server

EXPOSE 22

# entrypoint runs mount -a to mount fstab entry above after container is started
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

