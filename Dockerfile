FROM debian:latest


RUN echo "echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list" >> /etc/apt/sources.list.d/jellyfin.list

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y openssh-server nfs-common netbase jellyfin-ffmpeg

RUN mkdir -p /transcodes

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]
