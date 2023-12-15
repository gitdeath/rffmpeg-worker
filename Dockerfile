FROM debian:latest

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y  curl gnupg 
    
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg

RUN echo 'nfs-server:/transcodes /mnt nfs rw,nolock,actimeo=1 0 0' >> /etc/apt/sources.list.d/jellyfin.sources >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'export VERSION_OS="$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )"' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'export VERSION_CODENAME="$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )"' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'export DPKG_ARCHITECTURE="$( dpkg --print-architecture )"' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'cat <<EOF | sudo tee /etc/apt/sources.list.d/jellyfin.sources' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'Types: deb' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'URIs: https://repo.jellyfin.org/${VERSION_OS}' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'Suites: ${VERSION_CODENAME}' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'Components: main' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'Architectures: ${DPKG_ARCHITECTURE}' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'Signed-By: /etc/apt/keyrings/jellyfin.gpg' >> /etc/apt/sources.list.d/jellyfin.sources
RUN echo 'EOF' >> /etc/apt/sources.list.d/jellyfin.sources

RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y openssh-server nfs-common netbase jellyfin-ffmpeg

RUN mkdir -p /transcodes

RUN service ssh start

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]
