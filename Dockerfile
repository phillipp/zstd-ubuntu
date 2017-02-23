FROM ubuntu:trusty-20170119

ARG DEB_VERSION
ARG DEB_PACKAGE

# Required system packages
RUN apt-get update \
    && apt-get install -y \
        wget \
        unzip \
        build-essential \
        libreadline6-dev \
        ruby-dev \
        libncurses5-dev \
        perl \
        libpcre3-dev \
        libssl-dev \
    && gem install fpm

RUN mkdir -p /build/root
WORKDIR /build

# Download packages
RUN wget -O zstd-$DEB_VERSION.tar.gz https://github.com/facebook/zstd/archive/v$DEB_VERSION.tar.gz \
    && tar xfz zstd-$DEB_VERSION.tar.gz

# Compile and install
RUN cd /build/zstd-$DEB_VERSION \
    && make install DESTDIR=/build/root

# Build deb
RUN fpm -s dir -t deb \
    -n libzstd0 \
    -v $DEB_VERSION-$DEB_PACKAGE \
    -C /build/root \
    -p libzstd0_VERSION_ARCH.deb \
    --description 'a high performance web server and a reverse proxy server' \
    --maintainer 'Phillipp Röll <phillipp.roell@trafficplex.de>' \
    --deb-build-depends build-essential \
    usr/local/lib usr/local/include

# Build deb
RUN fpm -s dir -t deb \
    -n zstd \
    -v $DEB_VERSION-$DEB_PACKAGE \
    -C /build/root \
    -p zstd_VERSION_ARCH.deb \
    --depends "libzstd0 = $DEB_VERSION-$DEB_PACKAGE" \
    --description 'a high performance web server and a reverse proxy server' \
    --maintainer 'Phillipp Röll <phillipp.roell@trafficplex.de>' \
    --deb-build-depends build-essential \
    usr/local/bin usr/local/share
