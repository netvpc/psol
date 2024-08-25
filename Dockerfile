FROM debian:bookworm

RUN apt update && \
    apt install -y --no-install-recommends \
    build-essential zlib1g-dev \
    libncurses5-dev libgdbm-dev \
    libnss3-dev libssl-dev \
    libreadline-dev libffi-dev ca-certificates \
    pkg-config wget git curl unzip lsb-release rsync sudo libjemalloc-dev gperf \
    uuid-dev && \
    rm -rf /var/lib/apt/lists/*

RUN cd /tmp/ && \
    wget https://www.python.org/ftp/python/2.7.9/Python-2.7.9.tgz && \
    tar -xzvf Python-2.7.9.tgz && \
    cd Python-2.7.9 && \
    ./configure && \
    make -j $(nproc) && \
    make altinstall && \
    update-alternatives --install /usr/bin/python python /usr/local/bin/python2.7 100

WORKDIR /usr/src
RUN git clone -c advice.detachedHead=false --recursive https://github.com/apache/incubator-pagespeed-mod.git

COPY ./incubator-pagespeed-mod-aarch64.patch  /usr/src/incubator-pagespeed-mod-aarch64.patch
COPY ./incubator-pagespeed-mod-armv7l.patch /usr/src/incubator-pagespeed-mod-armv7l.patch
COPY ./incubator-pagespeed-mod-x86_64.patch /usr/src/incubator-pagespeed-mod-x86_64.patch

WORKDIR /usr/src/incubator-pagespeed-mod
RUN git reset --hard 409bd76fd6eafc4cf1c414e679f3e912447a6a31
RUN git submodule update --init --recursive --jobs=$(nproc) --force
RUN git reset --soft 2ce278dbbbeeeb6543cf1e970ba47d99726f893a
RUN git show 409bd76fd6eafc4cf1c414e679f3e912447a6a31:.gitmodules > .gitmodules
VOLUME [ "/dist" ]
COPY entrypoint.sh /usr/bin/entrypoint.sh
ENTRYPOINT ["/usr/bin/entrypoint.sh"]