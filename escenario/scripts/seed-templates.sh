#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$SCRIPT_DIR}"
SCENARIO_DIR="${SCENARIO_DIR:-$REPO_ROOT/escenario}"

ensure_config_tree() {
  local dst="$1"
  mkdir -p "$dst/config"
  mkdir -p "$dst/config/certs"
  mkdir -p "$dst/config/crypto/as"
  mkdir -p "$dst/config/crypto/ca"
  mkdir -p "$dst/config/crypto/trc"
  mkdir -p "$dst/config/keys"
}

seed_core() {
  ensure_config_tree "$1"
}

seed_leaf() {
  ensure_config_tree "$1"
}

seed_host() {
  local dst="$1"
  mkdir -p "$dst/config"
  if [[ -f "$REPO_ROOT/examples/endhost/scion-orchestrator.toml" ]]; then
    cp -f "$REPO_ROOT/examples/endhost/scion-orchestrator.toml" "$dst/config/"
  fi
  if [[ -f "$REPO_ROOT/examples/endhost-ovgu/sciond.toml" ]]; then
    cp -f "$REPO_ROOT/examples/endhost-ovgu/sciond.toml" "$dst/config/sciond.toml"
  fi
}

for n in \
  "$SCENARIO_DIR/ISD1/AS110" "$SCENARIO_DIR/ISD1/AS111" \
  "$SCENARIO_DIR/ISD2/AS210" "$SCENARIO_DIR/ISD2/AS211" \
  "$SCENARIO_DIR/ISD3/AS310" "$SCENARIO_DIR/ISD3/AS311" \
  "$SCENARIO_DIR/ISD4/AS410" "$SCENARIO_DIR/ISD4/AS411"; do
  seed_core "$n"
done

for n in \
  "$SCENARIO_DIR/ISD1/AS112" "$SCENARIO_DIR/ISD1/AS113" "$SCENARIO_DIR/ISD1/AS114" \
  "$SCENARIO_DIR/ISD2/AS212" "$SCENARIO_DIR/ISD2/AS213" "$SCENARIO_DIR/ISD2/AS214" \
  "$SCENARIO_DIR/ISD3/AS312" "$SCENARIO_DIR/ISD3/AS313" "$SCENARIO_DIR/ISD3/AS314" \
  "$SCENARIO_DIR/ISD4/AS412" "$SCENARIO_DIR/ISD4/AS413" "$SCENARIO_DIR/ISD4/AS414"; do
  seed_leaf "$n"
done

for n in \
  "$SCENARIO_DIR/ISD1/HostA" "$SCENARIO_DIR/ISD1/HostB" \
  "$SCENARIO_DIR/ISD2/HostA" "$SCENARIO_DIR/ISD2/HostB" \
  "$SCENARIO_DIR/ISD3/HostA" "$SCENARIO_DIR/ISD3/HostB" \
  "$SCENARIO_DIR/ISD4/HostA" "$SCENARIO_DIR/ISD4/HostB"; do
  seed_host "$n"
done

echo "Plantillas preparadas sin borrar PKI en: $SCENARIO_DIR"

