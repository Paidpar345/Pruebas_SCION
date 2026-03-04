# ── Etapa 1: compilar scion-orchestrator
FROM golang:1.24-bookworm AS builder
WORKDIR /src
COPY . .
RUN go build -ldflags="-s -w" -o scion-orchestrator .

# ── Etapa 2: runtime
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y wget ca-certificates && \
    cd /tmp && \
    wget -q https://github.com/scionproto/scion/releases/download/v0.12.0/scion_0.12.0_deb_amd64.tar.gz && \
    tar xfz scion_0.12.0_deb_amd64.tar.gz && \
    apt-get install -y ./scion*.deb && \
    rm -rf /tmp/scion* && apt-get clean

COPY --from=builder /src/scion-orchestrator /usr/local/bin/scion-orchestrator

RUN mkdir -p /scion/bin /scion/config /var/lib/scion /var/log/scion && \
    for b in scion-router scion-control scion-daemon scion-dispatcher scion-pki scion; do \
      ln -sf /usr/bin/$b /scion/bin/$b 2>/dev/null || true; \
    done

WORKDIR /scion

ENTRYPOINT ["scion-orchestrator", "run", "-c", "/scion/config/scion-orchestrator.toml"]
