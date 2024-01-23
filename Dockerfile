ARG PG_VERSION=15

FROM postgres:$PG_VERSION-bookworm
ARG PG_VERSION

RUN apt update && apt install -y curl wget make jq
# Install Lantern
RUN cd /tmp && \
    LANTERN_VERSION=$(curl -s "https://api.github.com/repos/lanterndata/lantern/releases/latest" | jq ".tag_name" | sed 's/"//g') && \
    LANTERN_VERSION_NUMBER=$(echo $LANTERN_VERSION | sed 's/^.\{1\}//') && \
    wget https://github.com/lanterndata/lantern/releases/download/${LANTERN_VERSION}/lantern-${LANTERN_VERSION_NUMBER}.tar -O lantern.tar && \
    tar xf lantern.tar && \
    cd lantern-${LANTERN_VERSION_NUMBER} && \
    make install && \
    cd /tmp && \
    rm -rf lantern*

# Install extras
RUN cd /tmp && \
    LANTERN_EXTRAS_VERSION=$(curl -s "https://api.github.com/repos/lanterndata/lantern_extras/releases/latest" | jq ".tag_name" | sed 's/"//g') && \
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
    if [[ $OS_ARCH == *"arm"* ]]; then PACKAGE_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-aarch64-${ONNX_VERSION}.tgz"; fi && \
    mkdir -p /usr/local/lib && \
    cd /usr/local/lib && \
    wget $PACKAGE_URL && \
    tar xzf ./onnx*.tgz && \
    rm -rf ./onnx*.tgz && \
    mv ./onnx* ./onnxruntime && \
    echo /usr/local/lib/onnxruntime/lib > /etc/ld.so.conf.d/onnx.conf && \
    ldconfig

# Install Libssl
RUN apt-get update && \
    apt-get install -y libssl3 && \
    rm -rf /var/lib/apt/lists/*

# Cleanup
RUN apt-get autoremove --purge -y curl wget make && \
    apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives