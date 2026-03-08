#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export PATH="$PWD/bin:$PATH"

mkdir -p ./config/certs

while true; do
  if ./scion-orchestrator run; then
    exit 0
  fi
  echo "[host-run] bootstrap falló; reintentando en 2s..."
  sleep 2
done
