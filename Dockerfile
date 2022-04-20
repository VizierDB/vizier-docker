FROM alpine:3.12.4

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apk add --no-cache --virtual .build-deps zlib-dev curl binutils cmake \
    && GLIBC_VER="2.29-r0" \
    && ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" \
    && GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-9.1.0-2-x86_64.pkg.tar.xz" \
    && GCC_LIBS_SHA256="91dba90f3c20d32fcf7f1dbe91523653018aa0b8d2230b00f822f6722804cf08" \
    && ZLIB_URL="https://archive.archlinux.org/packages/z/zlib/zlib-1%3A1.2.11-3-x86_64.pkg.tar.xz" \
    && ZLIB_SHA256=17aede0b9f8baa789c5aa3f358fbf8c68a5f1228c5e6cba1a5dd34102ef4d4e5 \
    && curl -kLfsS https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub \
    && SGERRAND_RSA_SHA256="823b54589c93b02497f1ba4dc622eaef9c813e6b0f0ebbb2f771e32adf9f4ef2" \
    && echo "${SGERRAND_RSA_SHA256} */etc/apk/keys/sgerrand.rsa.pub" | sha256sum -c - \
    && curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/glibc-${GLIBC_VER}.apk \
    && apk add --no-cache /tmp/glibc-${GLIBC_VER}.apk \
    && curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk > /tmp/glibc-bin-${GLIBC_VER}.apk \
    && apk add --no-cache /tmp/glibc-bin-${GLIBC_VER}.apk \
    && curl -Ls ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-i18n-${GLIBC_VER}.apk > /tmp/glibc-i18n-${GLIBC_VER}.apk \
    && apk add --no-cache /tmp/glibc-i18n-${GLIBC_VER}.apk \
    && /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true \
    && echo "export LANG=$LANG" > /etc/profile.d/locale.sh \
    && curl -LfsS ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.xz \
    && echo "${GCC_LIBS_SHA256} */tmp/gcc-libs.tar.xz" | sha256sum -c - \
    && mkdir /tmp/gcc \
    && tar -xf /tmp/gcc-libs.tar.xz -C /tmp/gcc \
    && mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib \
    && strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* \
    #&& curl -LfsS ${ZLIB_URL} -o /tmp/libz.tar.xz \
    #&& echo "${ZLIB_SHA256} */tmp/libz.tar.xz" | sha256sum -c - \
    && mkdir /tmp/libz \
    #&& tar -xf /tmp/libz.tar.xz -C /tmp/libz \
    #&& mv /tmp/libz/usr/lib/libz.so* /usr/glibc-compat/lib \
    && apk del --purge .build-deps glibc-i18n \
    && rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar.xz /tmp/libz /tmp/libz.tar.xz /var/cache/apk/* \
    && apk add --no-cache curl

RUN apk add --no-cache --virtual .build-deps openjdk8 git gcc g++ python3 python3-dev py3-pip geos-dev py3-kiwisolver py3-matplotlib zlib-dev jpeg-dev

RUN pip3 install cpython setuptools wheel numpy bokeh matplotlib astor pandas shapely pyspark

RUN apk add --no-cache \
            build-base \
            cmake \
            bash \
            boost-dev \
            autoconf \
            zlib-dev \
            flex \
            bison

RUN pip install --no-cache-dir six pytest numpy cython
RUN pip install --no-cache-dir pandas

ARG ARROW_VERSION=5.0.0
ARG ARROW_URL=https://codeload.github.com/apache/arrow/tar.gz/refs/tags/apache-arrow-
ARG ARROW_SHA1=78fb38f212fa49029aff24c669a39648d9b4e68b
ARG ARROW_BUILD_TYPE=release

ENV ARROW_HOME=/usr/local \
    PARQUET_HOME=/usr/local

# Download and build apache-arrow
RUN mkdir /arrow \
    && apk add --no-cache curl \
    && curl -o /tmp/apache-arrow.tar.gz -SL ${ARROW_URL}${ARROW_VERSION} \
    && echo "$ARROW_SHA1" `sha1sum /tmp/apache-arrow.tar.gz` \
    && echo "$ARROW_SHA1 *apache-arrow.tar.gz" | sha1sum /tmp/apache-arrow.tar.gz \
    && tar -xvf /tmp/apache-arrow.tar.gz -C /arrow --strip-components 1 \
    && mkdir -p /arrow/cpp/build \
    && cd /arrow/cpp/build \
    && cmake -DCMAKE_BUILD_TYPE=$ARROW_BUILD_TYPE \
          -DCMAKE_INSTALL_LIBDIR=lib \
          -DCMAKE_INSTALL_PREFIX=$ARROW_HOME \
          -DARROW_PARQUET=on \
          -DARROW_PYTHON=on \
          -DARROW_PLASMA=on \
          -DARROW_WITH_SNAPPY=ON \
          -DARROW_BUILD_TESTS=OFF \
          .. \
    && make -j$(nproc) \
    && make install \
    && cd /arrow/python \
    && python3 setup.py build_ext --build-type=$ARROW_BUILD_TYPE --with-parquet \
    && python3 setup.py install \
    && rm -rf /arrow /tmp/apache-arrow.tar.gz

ARG CACHE_DATE
RUN wget https://maven.mimirdb.info/info/vizierdb/vizier; \
    chmod +x vizier; \
    mv vizier /usr/bin/;


ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"

ENV COURSIER_CACHE=/usr/local/mimir/cache

# Run vizier to prefetch dependencies
RUN /usr/bin/vizier --help

EXPOSE 5000


RUN mkdir /data
VOLUME ["/data"]
ENV USER_DATA_DIR=/data/

# --connect-from-any-host needed, since connections will be coming in over the
#   docker virtual network.  Docker controls the localhost port... nothing we
#   can do about that.
ENTRYPOINT ["/usr/bin/vizier", "--connect-from-any-host"]
