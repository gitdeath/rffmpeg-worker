FROM debian:bullseye
RUN apt update && \
    apt -y install curl gnupg
    
RUN curl -fsSL https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jellyfin.gpg

RUN echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" >> /etc/apt/sources.list.d/jellyfin.list

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y openssh-server nfs-common netbase jellyfin-ffmpeg6

RUN mkdir -p /transcodes \
    mkdir -p /root/.ssh \
    mkdir -p /config/rffmpeg/.ssh

RUN ln -s /config/rffmpeg/.ssh /root/.ssh

RUN echo 'nfs-server:/transcodes /transcodes nfs rw,nolock,actimeo=1 0 0' > /etc/fstab

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]
