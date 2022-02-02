FROM debian:buster-slim

#### Mopidy Setup.  Forked from Wernight/docker-mopidy and sabbaman/mopidy-snapcast-docker

# Base Install
RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        dumb-init \
        gnupg \
        gstreamer1.0-alsa \
        gstreamer1.0-plugins-bad \
        python3-crypto \
        python3-distutils \
        python3-pip

# Install Mopidy
RUN set -ex \
 && curl -L https://apt.mopidy.com/mopidy.gpg | apt-key add - \
 && curl -L https://apt.mopidy.com/mopidy.list -o /etc/apt/sources.list.d/mopidy.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mopidy

# Install Mopidy plugins
RUN pip3 install Mopidy-Local
RUN pip3 install Mopidy-Iris
RUN pip3 install Mopidy-MPD
RUN pip3 install Mopidy-Jellyfin

RUN set -ex \
 && mkdir -p /var/lib/mopidy/.config \
 && ln -s /mopidy_config /var/lib/mopidy/.config/mopidy

# Start helper script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default configuration
COPY mopidy.conf /mopidy_config/mopidy.conf

# Copy the pulse-client configuratrion.
COPY pulse-client.conf /etc/pulse/client.conf

# Allows any user to run mopidy, but runs by default as a randomly generated UID/GID.
ENV HOME=/var/lib/mopidy

# Final Mopidy steps

VOLUME ["/var/lib/mopidy/local", "/var/lib/mopidy/media"]

EXPOSE 6600 6680

ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]

### Snapcast setup
# Taken and adapted from: https://github.com/nolte/docker-snapcast/blob/master/DockerfileServerX86
ARG SNAPCASTVERSION=0.26.0
ARG SNAPCASTDEP_SUFFIX=-1

# Download snapcast package
RUN apt-get update && apt-get install wget -y
RUN curl -sL -o /tmp/snapserver.deb 'https://github.com/badaix/snapcast/releases/download/v'$SNAPCASTVERSION'/snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb'

# Install snapcast package
RUN dpkg -i --force-all /tmp/snapserver.deb
RUN apt-get -f install -y
RUN rm /tmp/snapserver.deb

# Create config directory
RUN mkdir -p /snap_config
COPY snapserver.conf /snap_config/snapserver.conf

# Expose TCP port used to stream audio data to snapclient instances
EXPOSE 1704 1705 1780

# Run Mopidy/Snapcast
COPY run_mosnap.sh /run_mosnap.sh
RUN chmod +x /run_mosnap.sh
CMD ["/run_mosnap.sh"]

### Cleanup

RUN set -ex \
       apt-get purge --auto-remove -y \
       curl \
       gcc \
       build-essential \
       python3-dev \
       && apt-get clean \
       && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
