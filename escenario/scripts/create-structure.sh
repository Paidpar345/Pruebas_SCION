#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/alonso/Escritorio/scion-orchestrator/escenario"

mkdir -p "$SCENARIO_DIR"

for isd in 1 2 3 4; do
  mkdir -p "$SCENARIO_DIR/ISD${isd}"
done

mkdir -p \
  "$SCENARIO_DIR/ISD1/AS110/config" \
  "$SCENARIO_DIR/ISD1/AS111/config" \
  "$SCENARIO_DIR/ISD1/AS112/config" \
  "$SCENARIO_DIR/ISD1/AS113/config" \
  "$SCENARIO_DIR/ISD1/AS114/config" \
  "$SCENARIO_DIR/ISD1/HostA/config" \
  "$SCENARIO_DIR/ISD1/HostB/config"

mkdir -p \
  "$SCENARIO_DIR/ISD2/AS210/config" \
  "$SCENARIO_DIR/ISD2/AS211/config" \
  "$SCENARIO_DIR/ISD2/AS212/config" \
  "$SCENARIO_DIR/ISD2/AS213/config" \
  "$SCENARIO_DIR/ISD2/AS214/config" \
  "$SCENARIO_DIR/ISD2/HostA/config" \
  "$SCENARIO_DIR/ISD2/HostB/config"

mkdir -p \
  "$SCENARIO_DIR/ISD3/AS310/config" \
  "$SCENARIO_DIR/ISD3/AS311/config" \
  "$SCENARIO_DIR/ISD3/AS312/config" \
  "$SCENARIO_DIR/ISD3/AS313/config" \
  "$SCENARIO_DIR/ISD3/AS314/config" \
  "$SCENARIO_DIR/ISD3/HostA/config" \
  "$SCENARIO_DIR/ISD3/HostB/config"

mkdir -p \
  "$SCENARIO_DIR/ISD4/AS410/config" \
  "$SCENARIO_DIR/ISD4/AS411/config" \
  "$SCENARIO_DIR/ISD4/AS412/config" \
  "$SCENARIO_DIR/ISD4/AS413/config" \
  "$SCENARIO_DIR/ISD4/AS414/config" \
  "$SCENARIO_DIR/ISD4/HostA/config" \
  "$SCENARIO_DIR/ISD4/HostB/config"

echo "Estructura creada en: $SCENARIO_DIR"
