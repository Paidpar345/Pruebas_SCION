#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export PATH="$PWD/bin:$PATH"

mkdir -p ./config/certs
mkdir -p /etc/scion/crypto/as

if [[ -f ./config/crypto/as/cp-as.key ]]; then
  cp -f ./config/crypto/as/cp-as.key /etc/scion/crypto/as/cp-as.key
  chmod 600 /etc/scion/crypto/as/cp-as.key
fi

exec ./scion-orchestrator run
