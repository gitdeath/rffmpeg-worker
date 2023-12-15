FROM ubuntu:latest

RUN apt update && apt install openssh-server nfs-common netbase jellyfin-ffmpeg6 -y

RUN mkdir -p /transcodes

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]
