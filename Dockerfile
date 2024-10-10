ARG PG_VERSION=15

FROM postgres:$PG_VERSION-bookworm
ARG LANTERN_VERSION=0.4.0
ARG PGVECTOR_VERSION="v0.7.4-lanterncloud"
ARG BUILD_FROM_SOURCE="no"
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

# Install PGVector
RUN git clone https://github.com/lanterndata/pgvector.git --recursive -b ${PGVECTOR_VERSION} /tmp/pgvector && \
    cd /tmp/pgvector && \
    # Set max ef_search to 50000
    sed -i "s/#define HNSW_MAX_EF_SEARCH.*/#define HNSW_MAX_EF_SEARCH 50000/g" src/hnsw.h && \
    # Make pgvector trusted extension
    echo "trusted=true" >> vector.control && \
    make OPTFLAGS="" -j && \
    make OPTFLAGS="" install && \
    rm -rf /tmp/pgvector

# Install lantern and lantern extras
RUN cd /tmp && \
    case "$BUILD_FROM_SOURCE" in \
        no|false|0) \
            wget -q https://github.com/lanterndata/lantern/releases/download/v${LANTERN_VERSION}/lantern-${LANTERN_VERSION}.tar -O lantern.tar && \
            tar xf lantern.tar && \
            cd lantern-${LANTERN_VERSION} && \
            make install && \
            cd /tmp && \
            rm -rf lantern* ;; \
        *) \
            curl https://sh.rustup.rs -sSf | sh -s -- -y && \
            . "$HOME/.cargo/env" && \
            apt install pkg-config libssl-dev -y && \
            cargo install cargo-pgrx --version 0.11.3 && \
            cargo pgrx init --pg15 /usr/bin/pg_config && \
            git clone --recursive  https://github.com/lanterndata/lantern.git -b "v${LANTERN_VERSION}" && \
            cd lantern && \
            ORT_STRATEGY=system cargo pgrx install --release --pg-config /usr/bin/pg_config --package lantern_extras && \
            cmake -S ./lantern_hnsw -B ./build -DBUILD_FOR_DISTRIBUTING=YES -DMARCH_NATIVE=OFF && \
            make -C ./build install -j && \
            rustup self uninstall -y && \
            cd /tmp && rm -rf lantern* ;; \
    esac

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
