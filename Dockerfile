FROM debian:bookworm

RUN apt update && \
    apt install -y --no-install-recommends \
    build-essential zlib1g-dev \
    libncurses5-dev libgdbm-dev \
    libnss3-dev libssl-dev \
    libreadline-dev libffi-dev ca-certificates \
    pkg-config wget git curl unzip lsb-release rsync sudo libjemalloc-dev gperf && \
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

RUN wget https://gitlab.com/gusco/ngx_pagespeed_arm/-/raw/master/incubator-pagespeed-mod-aarch64.patch -O /usr/src/incubator-pagespeed-mod-aarch64.patch
RUN wget https://gitlab.com/gusco/ngx_pagespeed_arm/-/raw/master/incubator-pagespeed-mod-armv7l.patch -O /usr/src/incubator-pagespeed-mod-armv7l.patch

WORKDIR /usr/src/incubator-pagespeed-mod
RUN git reset --hard 409bd76fd6eafc4cf1c414e679f3e912447a6a31
RUN git submodule update --init --recursive --jobs=$(nproc) --force
RUN git reset --soft 2ce278dbbbeeeb6543cf1e970ba47d99726f893a
RUN git show 409bd76fd6eafc4cf1c414e679f3e912447a6a31:.gitmodules > .gitmodules

COPY entrypoint.sh /usr/bin/entrypoint.sh
## ENTRYPOINT ["/usr/bin/entrypoint.sh"]

RUN bash -c ' \
    ARCH=$(uname -m) && \
    \
    declare -A PATCH_FILES=( \
        ["aarch64"]="../incubator-pagespeed-mod-aarch64.patch" \
        ["armv7l"]="../incubator-pagespeed-mod-armv7l.patch" \
    ) && \
        if [[ -n "${PATCH_FILES[$ARCH]}" ]]; then \
            echo "Applying patch for $ARCH..." && \
            patch -Np1 -i "${PATCH_FILES[$ARCH]}" ; \
        elif [[ "$ARCH" == "x86_64" ]]; then \
            touch install/debian/install_required_packages.sh && \
            touch install/debian/build_env.sh && \
            sed -i  /"run_with_log log\/install_deps.log"/d install/build_psol.sh && \
            sed -i s/"run_with_log log\/gyp.log"//g            install/build_psol.sh && \
            sed -i s/"run_with_log log\/psol_build.log"//g     install/build_psol.sh && \
            sed -i /"run_with_log \.\.\/\.\.\/log\/psol_automatic_build.log"/d install/build_psol.sh && \
            echo "x86_64 architecture detected. No patch applied." ; \
        else \
            echo "Unsupported architecture: $ARCH" && exit 1 ; \
        fi && \
    \
    GLIBC_VERSION=$(ldd --version | awk "NR==1 {print \$NF}") && \
    GLIBC_VERSION_NUMBER=$(echo "$GLIBC_VERSION" | awk -F. "{print \$1 * 100 + \$2}") && \
        if [[ "$GLIBC_VERSION_NUMBER" -ge 228 ]]; then \
            echo "glibc version $GLIBC_VERSION detected. Applying sed command..." && \
            sed -i "s/sys_siglist\\[signum\\]/strsignal(signum)/g" third_party/apr/src/threadproc/unix/signals.c ; \
        else \
            echo "glibc version $GLIBC_VERSION detected. No sed command applied." ; \
        fi && \
    \
    python build/gyp_chromium --depth=. && \
    install/build_psol.sh --skip_tests \
    '