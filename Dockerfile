FROM ubuntu:trusty-20170119

ARG DEB_MAJOR
ARG DEB_MINOR
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
RUN wget https://openresty.org/download/openresty-$DEB_VERSION.tar.gz \
    && tar xfz openresty-$DEB_VERSION.tar.gz

ADD patches/* /tmp/patches/

# Compile and install openresty
RUN cd /build/openresty-$DEB_VERSION \
    && patch -p1 bundle/nginx-$DEB_MAJOR/src/http/modules/ngx_http_static_module.c < /tmp/patches/openresty-static.patch \
    && patch -p1 bundle/nginx-$DEB_MAJOR/src/http/modules/ngx_http_upstream_keepalive_module.c < /tmp/patches/nginx-upstream-ka-pooling.patch \
    && ./configure \
        --prefix=/usr/share/nginx \
        -j6 \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-client-body-temp-path=/var/lib/nginx/body \
        --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
        --http-log-path=/var/log/nginx/access.log \
        --http-proxy-temp-path=/var/lib/nginx/proxy \
        --http-scgi-temp-path=/var/lib/nginx/scgi \
        --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
        --lock-path=/var/lock/nginx.lock \
        --pid-path=/run/nginx.pid \
        --with-pcre-jit \
        --with-debug \
        --with-http_addition_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_ssl_module \
        --with-http_sub_module \
        --with-ipv6 \
    && make -j8 \
    && make install DESTDIR=/build/root

COPY scripts/* nginx-scripts/
COPY conf/* nginx-conf/

# Add extras to the build root
RUN cd /build/root \
    && mkdir \
        etc/init \
        etc/logrotate.d \
        var/lib \
        var/lib/nginx \
        usr/sbin \
    && mv usr/share/nginx/nginx/sbin/nginx usr/sbin/nginx && rm -rf usr/share/nginx/nginx/sbin \
    && mv usr/share/nginx/nginx/html usr/share/nginx/html && rm -rf usr/share/nginx/nginx \
    && rm -rf etc/nginx \
    && cp /build/nginx-scripts/upstart.conf etc/init/nginx.conf \
    && cp /build/nginx-conf/logrotate etc/logrotate.d/nginx

# Build deb
RUN fpm -s dir -t deb \
    -n openresty \
    -v $DEB_VERSION-$DEB_PACKAGE \
    -C /build/root \
    -p openresty_VERSION_ARCH.deb \
    --description 'a high performance web server and a reverse proxy server' \
    --url 'http://openresty.org/' \
    --category httpd \
    --maintainer 'Phillipp Röll <phillipp.roell@trafficplex.de>' \
    --depends wget \
    --depends unzip \
    --depends libncurses5 \
    --depends libreadline6 \
    --deb-build-depends build-essential \
    --replaces 'nginx-full' \
    --provides 'nginx-full' \
    --conflicts 'nginx-full' \
    --replaces 'nginx-common' \
    --provides 'nginx-common' \
    --conflicts 'nginx-common' \
    --after-install nginx-scripts/postinstall \
    --before-install nginx-scripts/preinstall \
    --after-remove nginx-scripts/postremove \
    --before-remove nginx-scripts/preremove \
    etc run usr var
