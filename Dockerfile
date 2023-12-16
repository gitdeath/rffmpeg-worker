FROM debian:latest

#RUN echo 'deb [arch=amd64] https://repo.jellyfin.org/debian bullseye main' >> /etc/apt/sources.list.d/jellyfin.sources 
RUN echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/debian buster main" >> /etc/apt/sources.list.d/jellyfin.list

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y openssh-server nfs-common netbase jellyfin-ffmpeg

RUN mkdir -p /transcodes

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]
