#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/alonso/Escritorio/scion-orchestrator"
SCENARIO_DIR="/home/alonso/Escritorio/scion-orchestrator/escenario"
PKI_DIR="$SCENARIO_DIR/pki"
TRC_DIR="$SCENARIO_DIR/trc"
TIME_ENV="$SCENARIO_DIR/scripts/pki-time.env"

if command -v scion-pki >/dev/null 2>&1; then
  SCION_PKI="$(command -v scion-pki)"
elif [[ -x "$SCENARIO_DIR/bin/scion-pki" ]]; then
  SCION_PKI="$SCENARIO_DIR/bin/scion-pki"
elif [[ -x "$REPO_ROOT/bin/scion-pki" ]]; then
  SCION_PKI="$REPO_ROOT/bin/scion-pki"
else
  echo "ERROR: no encuentro scion-pki"
  exit 1
fi

if [[ ! -f "$TIME_ENV" ]]; then
  echo "ERROR: falta $TIME_ENV"
  echo "Ejecuta primero generate-pki.sh"
  exit 1
fi

# shellcheck disable=SC1090
source "$TIME_ENV"

declare -A CORE_A
declare -A CORE_B

CORE_A["1"]="1-110"
CORE_B["1"]="1-111"
CORE_A["2"]="2-210"
CORE_B["2"]="2-211"
CORE_A["3"]="3-310"
CORE_B["3"]="3-311"
CORE_A["4"]="4-410"
CORE_B["4"]="4-411"

ALL_AS=(
  "1-110" "1-111" "1-112" "1-113" "1-114"
  "2-210" "2-211" "2-212" "2-213" "2-214"
  "3-310" "3-311" "3-312" "3-313" "3-314"
  "4-410" "4-411" "4-412" "4-413" "4-414"
)

declare -A AS_DIR
for asid in "${ALL_AS[@]}"; do
  isd="${asid%%-*}"
  asnum="${asid#*-}"
  AS_DIR["$asid"]="$SCENARIO_DIR/ISD${isd}/AS${asnum}"
done

ensure_dir() {
  mkdir -p "$1"
}

write_trcs_json() {
  local file="$1"
  local isd="$2"
  cat > "$file" <<EOF
[
  {
    "id": {
      "isd": ${isd},
      "base_number": 1,
      "serial_number": 1
    }
  }
]
EOF
}

asn_only() {
  local isd_as="$1"
  echo "${isd_as#*-}"
}

write_trc_template() {
  local file="$1"
  local isd="$2"
  local core1_asn="$3"
  local core2_asn="$4"
  local root1="$5"
  local root2="$6"
  local reg1="$7"
  local reg2="$8"
  local sen1="$9"
  local sen2="${10}"

  cat > "$file" <<EOF
isd = ${isd}
description = "Initial TRC for ISD ${isd}"
serial_version = 1
base_version = 1
grace_period = "0s"
voting_quorum = 2

core_ases = [${core1_asn}, ${core2_asn}]
authoritative_ases = [${core1_asn}, ${core2_asn}]

cert_files = [
  "${root1}",
  "${root2}",
  "${reg1}",
  "${reg2}",
  "${sen1}",
  "${sen2}"
]

[validity]
not_before = ${NOT_BEFORE}
not_after = ${TRC_NOT_AFTER}
EOF
}

copy_trc_to_isd_nodes() {
  local isd="$1"
  local trc_file="$2"

  for asid in "${ALL_AS[@]}"; do
    local current_isd="${asid%%-*}"
    [[ "$current_isd" != "$isd" ]] && continue

    local node_dir="${AS_DIR[$asid]}"
    ensure_dir "$node_dir/config/crypto/trc"
    ensure_dir "$node_dir/config/certs"
    ensure_dir "$node_dir/config"

    rm -f "$node_dir/config/crypto/trc/"*.trc || true
    rm -f "$node_dir/config/certs/"*.trc || true

    cp -f "$trc_file" "$node_dir/config/crypto/trc/ISD${isd}-B1-S1.trc"
    cp -f "$trc_file" "$node_dir/config/certs/ISD${isd}-B1-S1.trc"
    write_trcs_json "$node_dir/config/trcs.json" "$isd"
  done
}

rm -rf "$TRC_DIR"
mkdir -p "$TRC_DIR"

for isd in 1 2 3 4; do
  core1="${CORE_A[$isd]}"
  core2="${CORE_B[$isd]}"

  num1="$(asn_only "$core1")"
  num2="$(asn_only "$core2")"

  isd_dir="$TRC_DIR/ISD${isd}"
  ensure_dir "$isd_dir"

  root1="$PKI_DIR/ISD${isd}/${num1}/root/cp-root.pem"
  root2="$PKI_DIR/ISD${isd}/${num2}/root/cp-root.pem"

  reg1="$PKI_DIR/ISD${isd}/${num1}/voting/regular-voting.pem"
  reg2="$PKI_DIR/ISD${isd}/${num2}/voting/regular-voting.pem"
  sen1="$PKI_DIR/ISD${isd}/${num1}/voting/sensitive-voting.pem"
  sen2="$PKI_DIR/ISD${isd}/${num2}/voting/sensitive-voting.pem"

  reg1_key="$PKI_DIR/ISD${isd}/${num1}/voting/regular-voting.key"
  reg2_key="$PKI_DIR/ISD${isd}/${num2}/voting/regular-voting.key"
  sen1_key="$PKI_DIR/ISD${isd}/${num1}/voting/sensitive-voting.key"
  sen2_key="$PKI_DIR/ISD${isd}/${num2}/voting/sensitive-voting.key"

  template="$isd_dir/ISD${isd}-B1-S1.toml"
  payload="$isd_dir/ISD${isd}-B1-S1.pld.der"

  part_reg_1="$isd_dir/ISD${isd}-B1-S1.reg.${num1}.trc"
  part_reg_2="$isd_dir/ISD${isd}-B1-S1.reg.${num2}.trc"
  part_sen_1="$isd_dir/ISD${isd}-B1-S1.sen.${num1}.trc"
  part_sen_2="$isd_dir/ISD${isd}-B1-S1.sen.${num2}.trc"

  final="$isd_dir/ISD${isd}-B1-S1.trc"

  for f in \
    "$root1" "$root2" \
    "$reg1" "$reg2" "$sen1" "$sen2" \
    "$reg1_key" "$reg2_key" "$sen1_key" "$sen2_key"
  do
    if [[ ! -f "$f" ]]; then
      echo "ERROR: falta fichero requerido: $f"
      exit 1
    fi
  done

  write_trc_template \
    "$template" "$isd" "$num1" "$num2" \
    "$root1" "$root2" "$reg1" "$reg2" "$sen1" "$sen2"

  "$SCION_PKI" trc payload \
    -t "$template" \
    -o "$payload"

  "$SCION_PKI" trc sign \
    "$payload" \
    "$reg1" \
    "$reg1_key" \
    --out "$part_reg_1"

  "$SCION_PKI" trc sign \
    "$payload" \
    "$reg2" \
    "$reg2_key" \
    --out "$part_reg_2"

  "$SCION_PKI" trc sign \
    "$payload" \
    "$sen1" \
    "$sen1_key" \
    --out "$part_sen_1"

  "$SCION_PKI" trc sign \
    "$payload" \
    "$sen2" \
    "$sen2_key" \
    --out "$part_sen_2"

  "$SCION_PKI" trc combine \
    "$part_reg_1" \
    "$part_reg_2" \
    "$part_sen_1" \
    "$part_sen_2" \
    --out "$final"

  copy_trc_to_isd_nodes "$isd" "$final"
done

echo "TRCs generadas en: $TRC_DIR"
echo "TRCs copiadas a cada AS en config/crypto/trc/ y config/certs/"

