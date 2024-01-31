ARG PG_VERSION=15

FROM postgres:$PG_VERSION-bookworm as build
ARG PG_VERSION
ARG TARGETARCH
ENV OS_ARCH="${TARGETARCH:-amd64}"

RUN apt update && \
    apt install -y curl wget make jq build-essential cmake git lsb-release pkg-config libssl-dev && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc |  apt-key add - && \
    apt update && \
    # Install postgres and dev files for C headers
    apt install -y postgresql-server-dev-$PG_VERSION

# Install Lantern
RUN cd /tmp && \
    LANTERN_VERSION=$(curl -s "https://api.github.com/repos/lanterndata/lantern/releases/latest" | jq ".tag_name" | sed 's/"//g') && \
    git clone https://github.com/lanterndata/lantern.git --recursive && \
    cd lantern && git checkout $LANTERN_VERSION && \
    mkdir build && cd build && \
    cmake -DBUILD_FOR_DISTRIBUTING=YES -DMARCH_NATIVE=OFF .. && \
    make install && \
    cd /tmp && rm -rf lantern

# Setup rust
RUN cd /tmp && \
    curl -k -o /tmp/rustup.sh https://sh.rustup.rs && \
    chmod +x /tmp/rustup.sh && \
    /tmp/rustup.sh -y && \
    . "$HOME/.cargo/env" && \
    cargo install cargo-pgrx --version 0.9.7 && \
    cargo pgrx init "--pg$PG_VERSION" $(which pg_config) && \
    rm -rf /tmp/rustup.sh

 
# Install Lantern Extras
RUN cd /tmp && \
    LANTERN_EXTRAS_VERSION=$(curl -s "https://api.github.com/repos/lanterndata/lantern_extras/releases/latest" | jq ".tag_name" | sed 's/"//g') && \
    git clone https://github.com/lanterndata/lantern_extras.git && \
    cd lantern_extras && git checkout $LANTERN_EXTRAS_VERSION && \
    . "$HOME/.cargo/env" && \
    cargo pgrx install --pg-config $(which pg_config) --package lantern_extras && \
    cd /tmp && rm -rf lantern_extras

# Setup onnxruntime for lantern extras
RUN cd /tmp && \
    ONNX_VERSION="1.16.1" && \
    PACKAGE_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz" && \
    if [[ $OS_ARCH == *"arm"* ]]; then PACKAGE_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-aarch64-${ONNX_VERSION}.tgz"; fi && \
    mkdir -p /usr/local/lib && \
    cd /usr/local/lib && \
    wget $PACKAGE_URL && \
    tar xzf ./onnx*.tgz && \
    rm -rf ./onnx*.tgz && \
    mv ./onnx* ./onnxruntime && \
    echo /usr/local/lib/onnxruntime/lib > /etc/ld.so.conf.d/onnx.conf && \
    ldconfig

# Cleanup
RUN apt-get autoremove --purge -y pkg-config python3 llvm clang jq curl wget build-essential cmake git postgresql-server-dev-$PG_VERSION && \
    . "$HOME/.cargo/env" && \
    rustup self uninstall -y && \
    apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG PG_VERSION=15
FROM postgres:$PG_VERSION-bookworm
ARG PG_VERSION

COPY --from=build /usr/share/postgresql/$PG_VERSION/extension /usr/share/postgresql/$PG_VERSION/extension
COPY --from=build /usr/lib/postgresql/$PG_VERSION/lib /usr/lib/postgresql/$PG_VERSION/lib
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /etc/ld.so.conf.d /etc/ld.so.conf.d
RUN apt update && \
    apt install ca-certificates -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    ldconfig

USER postgres
