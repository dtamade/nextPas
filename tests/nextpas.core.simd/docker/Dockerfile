# Multi-arch SIMD test image
# - i386/arm(32-bit): Debian bookworm
# - arm64/amd64: Ubuntu 24.04
# - riscv64: Ubuntu 24.04 + FPC snapshot
# - arm64 with USE_FPC_SNAPSHOT=1: FPC 3.3.1 snapshot (for NEON ASM testing)
ARG TARGETARCH
FROM debian:bookworm AS base-386
FROM debian:bookworm AS base-arm
FROM ubuntu:24.04 AS base-arm64
FROM ubuntu:24.04 AS base-amd64
FROM ubuntu:24.04 AS base-riscv64

FROM base-${TARGETARCH}

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
# Set USE_FPC_SNAPSHOT=1 to use FPC 3.3.1 snapshot instead of apt (for arm64 NEON ASM)
ARG USE_FPC_SNAPSHOT=0

# FPC snapshot URLs
ARG FPC_RISCV64_SNAPSHOT_URL="https://downloads.freepascal.org/fpc/snapshot/trunk/riscv64-linux/fpc-3.3.1.riscv64-linux.tar.gz"
ARG FPC_ARM64_SNAPSHOT_URL="https://downloads.freepascal.org/fpc/snapshot/trunk/aarch64-linux/fpc-3.3.1.aarch64-linux.tar.gz"

RUN apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true update \
  && apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    gzip \
  && if [ "${TARGETARCH}" = "riscv64" ]; then \
      apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true install -y --no-install-recommends \
        binutils \
        libc6-dev; \
      echo "[INFO] Installing FPC snapshot for ${TARGETARCH}: ${FPC_RISCV64_SNAPSHOT_URL}"; \
      mkdir -p /opt/fpc; \
      curl -L --retry 5 --retry-delay 2 --speed-limit 500 --speed-time 120 \
        -o /tmp/fpc.tar.gz "${FPC_RISCV64_SNAPSHOT_URL}"; \
      tar -xzf /tmp/fpc.tar.gz -C /opt/fpc; \
      ln -sf /opt/fpc/bin/fpc /usr/local/bin/fpc; \
      ln -sf /opt/fpc/lib/fpc/3.3.1/ppcrv64 /usr/local/bin/ppcrv64; \
      mkdir -p /etc; \
      echo '-Fu/opt/fpc/lib/fpc/3.3.1/units/riscv64-linux/*' > /etc/fpc.cfg; \
      echo '-Fl/opt/fpc/lib/fpc/3.3.1/units/riscv64-linux/rtl' >> /etc/fpc.cfg; \
      rm -rf /tmp/fpc.tar.gz; \
    elif [ "${TARGETARCH}" = "arm64" ] && [ "${USE_FPC_SNAPSHOT}" = "1" ]; then \
      apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true install -y --no-install-recommends \
        binutils \
        libc6-dev; \
      echo "[INFO] Installing FPC 3.3.1 snapshot for ${TARGETARCH} (NEON ASM support)"; \
      mkdir -p /opt/fpc; \
      curl -L --retry 5 --retry-delay 2 --speed-limit 500 --speed-time 120 \
        -o /tmp/fpc.tar.gz "${FPC_ARM64_SNAPSHOT_URL}"; \
      tar -xzf /tmp/fpc.tar.gz -C /opt/fpc; \
      ln -sf /opt/fpc/bin/fpc /usr/local/bin/fpc; \
      ln -sf /opt/fpc/lib/fpc/3.3.1/ppca64 /usr/local/bin/ppca64; \
      mkdir -p /etc; \
      echo '-Fu/opt/fpc/lib/fpc/3.3.1/units/aarch64-linux/*' > /etc/fpc.cfg; \
      echo '-Fl/opt/fpc/lib/fpc/3.3.1/units/aarch64-linux/rtl' >> /etc/fpc.cfg; \
      rm -rf /tmp/fpc.tar.gz; \
    else \
      echo "[INFO] Installing FPC from apt for ${TARGETARCH}"; \
      apt-get -o Acquire::Retries=5 -o Acquire::ForceIPv4=true install -y --no-install-recommends \
        fpc \
        fp-units-base \
        fp-units-fcl \
        fp-utils; \
    fi \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work
