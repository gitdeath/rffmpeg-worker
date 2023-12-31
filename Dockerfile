FROM debian:bullseye
# install requirements for adding jellyfin repo
RUN apt update && \
    apt -y install curl gnupg
# add jellyfin repo
RUN curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg
RUN echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" >> /etc/apt/sources.list.d/jellyfin.list
# install requirements to perform transcoding
RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y openssh-server nfs-common netbase jellyfin-ffmpeg6 iputils-ping
# allow root SSH
#RUN sed -i 's;#PermitRootLogin prohibit-password;PermitRootLogin yes;' /etc/ssh/sshd_config
# Make and set perms for /transcodes
RUN mkdir -p /transcodes
RUN chgrp users /transcodes
# setup fstab for mount to nfs-server
RUN echo 'nfs-server:/transcodes /transcodes nfs rw,nolock,actimeo=1 0 0' > /etc/fstab

# create transcodessh user with proper permsvim 
RUN useradd -u 7001 -g users -m transcodessh && \
    #groupadd -g 106 render && \
    usermod --shell /bin/bash transcodessh && \

    chown -R transcodessh /usr/lib/jellyfin-ffmpeg && \
    usermod -a -G video,users transcodessh
    


RUN service ssh start

# ensure nfs-server is reachable without a mounted /transcodes directory this worker can't do it's job
HEALTHCHECK --interval=5s --timeout=20s CMD ping -c 1 nfs-server

EXPOSE 22

# entrypoint runs mount -a to mount fstab entry above after container is started
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd","-D"]
