ARG PG_VERSION=15

FROM postgres:$PG_VERSION-bookworm
ARG LANTERN_VERSION=varik/external-index-router
ARG LANTERN_EXTRAS_VERSION=0.2.3
ARG PG_VERSION
ARG TARGETARCH
ARG PG_CRON_VERSION="7e91e72b1bebc5869bb900d9253cc9e92518b33f"
ENV OS_ARCH="${TARGETARCH:-amd64}"

RUN apt update && apt install -y curl wget make jq pgbouncer procps bc git-all gcc postgresql-server-dev-${PG_VERSION} cmake build-essential

# Install pg_cron
RUN git clone https://github.com/citusdata/pg_cron.git /tmp/pg_cron && \
    cd /tmp/pg_cron && \
    git checkout ${PG_CRON_VERSION} && \
    make -j && \
    make install

# Install pgvector
RUN git clone --branch v0.7.3-lanterncloud https://github.com/lanterndata/pgvector.git /tmp/pgvector && \
    cd /tmp/pgvector && \
    make OPTFLAGS="" -j && \
    make install

# Install Lantern
RUN cd /tmp && \
    git clone https://github.com/lanterndata/lantern.git -b $LANTERN_VERSION --recursive && \
    cd lantern && mkdir build && cd build && \
    cmake -DBUILD_FOR_DISTRIBUTING=1 .. && \
    make install -j && \
    cd /tmp && \
    rm -rf lantern

# Install extras
RUN cd /tmp && \
    wget https://github.com/lanterndata/lantern_extras/releases/download/${LANTERN_EXTRAS_VERSION}/lantern-extras-${LANTERN_EXTRAS_VERSION}.tar -O lantern-extras.tar && \
    tar xf lantern-extras.tar && \
    cd lantern-extras-${LANTERN_EXTRAS_VERSION} && \
    make install && \
    cd /tmp && \
    rm -rf lantern-extras*

# Setup onnxruntime for lantern extras
RUN cd /tmp && \
    ONNX_VERSION="1.16.1" && \
    PACKAGE_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz" && \
    case "$OS_ARCH" in \
        arm*|aarch64) \
            PACKAGE_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-aarch64-${ONNX_VERSION}.tgz"; \
    esac && \
    mkdir -p /usr/local/lib && \
    cd /usr/local/lib && \
    wget $PACKAGE_URL && \
    tar xzf ./onnx*.tgz && \
    rm -rf ./onnx*.tgz && \
    mv ./onnx* ./onnxruntime && \
    echo /usr/local/lib/onnxruntime/lib > /etc/ld.so.conf.d/onnx.conf && \
    ldconfig

# Install Libssl
RUN cd /tmp && \
    wget "http://http.us.debian.org/debian/pool/main/o/openssl/libssl1.1_1.1.1w-0+deb11u1_${OS_ARCH}.deb" && \
    dpkg -i "libssl1.1_1.1.1w-0+deb11u1_${OS_ARCH}.deb" && \
    rm -rf "libssl1.1_1.1.1w-0+deb11u1_${OS_ARCH}.deb"

# Cleanup
RUN apt-get autoremove --purge -y curl wget make && \
    apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY entrypoint/* /docker-entrypoint-initdb.d/
COPY scripts/*.sh /opt
COPY docker-entrypoint.sh /usr/local/bin/

USER postgres
EXPOSE 5432
EXPOSE 6432
