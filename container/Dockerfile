FROM ghcr.io/tianocore/containers/ubuntu-24-dev:latest

ENV EDKREPO_URL=https://github.com/tianocore/edk2-edkrepo/releases/download/edkrepo-v3.3.1/edkrepo-3.3.1.0.tar.gz

# Install edkrepo
RUN mkdir /edkrepo_install && \
    cd /edkrepo_install && \
    wget -O- ${EDKREPO_URL} | tar zxvf - && \
    cd edkrepo-3.3.1.0 && \
    ./install.py --system --no-prompt --user $(id -nu) && \
    mkdir -p /etc/edkrepo_skel && \
    cp -R /root/.edkrepo /etc/edkrepo_skel && \
    rm -rf /edkrepo_install

COPY init_edkrepo_conf.sh /usr/bin/init_edkrepo_conf
