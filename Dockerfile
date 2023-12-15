FROM debian:latest

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y  curl gnupg 
RUN add-apt-repository universe
RUN apt install --no-install-recommends --no-install-suggests -y openssh-server nfs-common netbase jellyfin-ffmpeg

RUN mkdir -p /transcodes

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]
