#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$SCRIPT_DIR}"
SCENARIO_DIR="${SCENARIO_DIR:-$REPO_ROOT/escenario}"

mkdir -p "$SCENARIO_DIR"
mkdir -p "$SCENARIO_DIR/bin"
mkdir -p "$SCENARIO_DIR/scripts"
mkdir -p "$SCENARIO_DIR/pki"
mkdir -p "$SCENARIO_DIR/trc"

for isd in 1 2 3 4; do
  mkdir -p "$SCENARIO_DIR/ISD${isd}"
done

for isd in 1 2 3 4; do
  base=$((isd * 100 + 10))
  mkdir -p "$SCENARIO_DIR/ISD${isd}/AS$((base+0))/config"
  mkdir -p "$SCENARIO_DIR/ISD${isd}/AS$((base+1))/config"
  mkdir -p "$SCENARIO_DIR/ISD${isd}/AS$((base+2))/config"
  mkdir -p "$SCENARIO_DIR/ISD${isd}/AS$((base+3))/config"
  mkdir -p "$SCENARIO_DIR/ISD${isd}/AS$((base+4))/config"
  mkdir -p "$SCENARIO_DIR/ISD${isd}/HostA/config"
  mkdir -p "$SCENARIO_DIR/ISD${isd}/HostB/config"
done

echo "Estructura creada en: $SCENARIO_DIR"

