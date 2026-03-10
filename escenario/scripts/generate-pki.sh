#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/alonso/Escritorio/scion-orchestrator"
SCENARIO_DIR="/home/alonso/Escritorio/scion-orchestrator/escenario"
PKI_DIR="$SCENARIO_DIR/pki"
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

ALL_AS=(
  "1-110" "1-111" "1-112" "1-113" "1-114"
  "2-210" "2-211" "2-212" "2-213" "2-214"
  "3-310" "3-311" "3-312" "3-313" "3-314"
  "4-410" "4-411" "4-412" "4-413" "4-414"
)

CORE_AS=(
  "1-110" "1-111"
  "2-210" "2-211"
  "3-310" "3-311"
  "4-410" "4-411"
)

LEAF_AS=(
  "1-112" "1-113" "1-114"
  "2-212" "2-213" "2-214"
  "3-312" "3-313" "3-314"
  "4-412" "4-413" "4-414"
)

declare -A AS_DIR
declare -A CORE_ISSUER
declare -A ISD_CORE_A

ISD_CORE_A["1"]="1-110"
ISD_CORE_A["2"]="2-210"
ISD_CORE_A["3"]="3-310"
ISD_CORE_A["4"]="4-410"

for asid in "${ALL_AS[@]}"; do
  isd="${asid%%-*}"
  asnum="${asid#*-}"
  AS_DIR["$asid"]="$SCENARIO_DIR/ISD${isd}/AS${asnum}"
  CORE_ISSUER["$asid"]="${ISD_CORE_A[$isd]}"
done

ensure_dir() {
  mkdir -p "$1"
}

write_subject_json() {
  local file="$1"
  local isd_as="$2"
  local common_name="$3"
  cat > "$file" <<EOF
{
  "isd_as": "${isd_as}",
  "common_name": "${common_name}",
  "organization": "Escenario SCION",
  "country": "ES"
}
EOF
}

copy_to_node() {
  local src="$1"
  local dst="$2"
  ensure_dir "$(dirname "$dst")"
  cp -f "$src" "$dst"
}

write_master_key() {
  local dst="$1"
  umask 077
  head -c 16 /dev/urandom | base64 | tr -d '\n' > "$dst"
  echo >> "$dst"
  chmod 600 "$dst"
}

generate_master_keys() {
  local node_dir="$1"
  ensure_dir "$node_dir/config/keys"
  write_master_key "$node_dir/config/keys/master0.key"
  write_master_key "$node_dir/config/keys/master1.key"
}

clean_node_crypto() {
  local node_dir="$1"
  rm -f "$node_dir"/config/crypto/as/* || true
  rm -f "$node_dir"/config/crypto/ca/* || true
  rm -f "$node_dir"/config/crypto/trc/* || true
  rm -f "$node_dir"/config/certs/* || true
  rm -f "$node_dir"/config/keys/master*.key || true
  ensure_dir "$node_dir/config/crypto/as"
  ensure_dir "$node_dir/config/crypto/ca"
  ensure_dir "$node_dir/config/crypto/trc"
  ensure_dir "$node_dir/config/certs"
  ensure_dir "$node_dir/config/keys"
}

write_time_env() {
  local not_before
  local trc_not_after
  local root_not_after
  local voting_not_after
  local ca_not_after
  local as_not_after

  not_before="$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)"
  trc_not_after="$(date -u -d '+365 days' +%Y-%m-%dT%H:%M:%SZ)"
  root_not_after="$(date -u -d '+370 days' +%Y-%m-%dT%H:%M:%SZ)"
  voting_not_after="$(date -u -d '+370 days' +%Y-%m-%dT%H:%M:%SZ)"
  ca_not_after="$(date -u -d '+370 days' +%Y-%m-%dT%H:%M:%SZ)"
  as_not_after="$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)"

  cat > "$TIME_ENV" <<EOF
export NOT_BEFORE="${not_before}"
export TRC_NOT_AFTER="${trc_not_after}"
export ROOT_NOT_AFTER="${root_not_after}"
export VOTING_NOT_AFTER="${voting_not_after}"
export CA_NOT_AFTER="${ca_not_after}"
export AS_NOT_AFTER="${as_not_after}"
EOF
}

copy_core_runtime_ca_layout() {
  local isd="$1"
  local asnum="$2"
  local node_dir="$3"
  local root_dir="$4"
  local ca_dir="$5"

  copy_to_node "$root_dir/cp-root.pem" "$node_dir/config/crypto/ca/cp-root.pem"
  copy_to_node "$ca_dir/cp-ca.pem" "$node_dir/config/crypto/ca/cp-ca.pem"
  copy_to_node "$ca_dir/cp-ca.pem" "$node_dir/config/crypto/ca/ISD${isd}-AS${asnum}.ca.crt"
  copy_to_node "$ca_dir/cp-ca.key" "$node_dir/config/crypto/ca/cp-ca.key"
}

generate_core_bundle() {
  local core_as="$1"
  local isd="${core_as%%-*}"
  local asnum="${core_as#*-}"
  local node_dir="${AS_DIR[$core_as]}"

  local base="$PKI_DIR/ISD${isd}/${asnum}"
  local subj_dir="$base/subjects"
  local root_dir="$base/root"
  local ca_dir="$base/ca"
  local vote_dir="$base/voting"
  local as_dir="$base/as"

  ensure_dir "$subj_dir"
  ensure_dir "$root_dir"
  ensure_dir "$ca_dir"
  ensure_dir "$vote_dir"
  ensure_dir "$as_dir"

  write_subject_json "$subj_dir/root.json" "$core_as" "ISD${isd} ${core_as} CP Root"
  write_subject_json "$subj_dir/ca.json" "$core_as" "ISD${isd} ${core_as} CP CA"
  write_subject_json "$subj_dir/regvote.json" "$core_as" "ISD${isd} ${core_as} Regular Voting"
  write_subject_json "$subj_dir/sensvote.json" "$core_as" "ISD${isd} ${core_as} Sensitive Voting"
  write_subject_json "$subj_dir/as.json" "$core_as" "${core_as} AS Certificate"

  "$SCION_PKI" certificate create \
    --force \
    --profile cp-root \
    --not-before "$NOT_BEFORE" \
    --not-after "$ROOT_NOT_AFTER" \
    "$subj_dir/root.json" \
    "$root_dir/cp-root.pem" \
    "$root_dir/cp-root.key"

  "$SCION_PKI" certificate create \
    --force \
    --profile cp-ca \
    --ca "$root_dir/cp-root.pem" \
    --ca-key "$root_dir/cp-root.key" \
    --not-before "$NOT_BEFORE" \
    --not-after "$CA_NOT_AFTER" \
    "$subj_dir/ca.json" \
    "$ca_dir/cp-ca.pem" \
    "$ca_dir/cp-ca.key"

  "$SCION_PKI" certificate create \
    --force \
    --profile regular-voting \
    --not-before "$NOT_BEFORE" \
    --not-after "$VOTING_NOT_AFTER" \
    "$subj_dir/regvote.json" \
    "$vote_dir/regular-voting.pem" \
    "$vote_dir/regular-voting.key"

  "$SCION_PKI" certificate create \
    --force \
    --profile sensitive-voting \
    --not-before "$NOT_BEFORE" \
    --not-after "$VOTING_NOT_AFTER" \
    "$subj_dir/sensvote.json" \
    "$vote_dir/sensitive-voting.pem" \
    "$vote_dir/sensitive-voting.key"

  "$SCION_PKI" certificate create \
    --force \
    --bundle \
    --profile cp-as \
    --ca "$ca_dir/cp-ca.pem" \
    --ca-key "$ca_dir/cp-ca.key" \
    --not-before "$NOT_BEFORE" \
    --not-after "$AS_NOT_AFTER" \
    "$subj_dir/as.json" \
    "$as_dir/chain.pem" \
    "$as_dir/cp-as.key"

  clean_node_crypto "$node_dir"
  generate_master_keys "$node_dir"

  copy_to_node "$as_dir/chain.pem" "$node_dir/config/crypto/as/ISD${isd}-AS${asnum}.pem"
  copy_to_node "$as_dir/cp-as.key" "$node_dir/config/crypto/as/cp-as.key"

  copy_core_runtime_ca_layout "$isd" "$asnum" "$node_dir" "$root_dir" "$ca_dir"

  copy_to_node "$vote_dir/regular-voting.pem" "$node_dir/config/crypto/trc/regular-voting.pem"
  copy_to_node "$vote_dir/regular-voting.key" "$node_dir/config/crypto/trc/regular-voting.key"
  copy_to_node "$vote_dir/sensitive-voting.pem" "$node_dir/config/crypto/trc/sensitive-voting.pem"
  copy_to_node "$vote_dir/sensitive-voting.key" "$node_dir/config/crypto/trc/sensitive-voting.key"

  head -c 32 /dev/urandom | base64 > "$node_dir/config/client1.secret"
}

generate_leaf_as_cert() {
  local asid="$1"
  local isd="${asid%%-*}"
  local asnum="${asid#*-}"
  local issuer="${CORE_ISSUER[$asid]}"
  local issuer_num="${issuer#*-}"
  local node_dir="${AS_DIR[$asid]}"

  local subj_dir="$PKI_DIR/ISD${isd}/${asnum}/subjects"
  local out_dir="$PKI_DIR/ISD${isd}/${asnum}/as"
  local issuer_ca_dir="$PKI_DIR/ISD${isd}/${issuer_num}/ca"
  local issuer_root_dir="$PKI_DIR/ISD${isd}/${issuer_num}/root"

  ensure_dir "$subj_dir"
  ensure_dir "$out_dir"

  write_subject_json "$subj_dir/as.json" "$asid" "${asid} AS Certificate"

  "$SCION_PKI" certificate create \
    --force \
    --bundle \
    --profile cp-as \
    --ca "$issuer_ca_dir/cp-ca.pem" \
    --ca-key "$issuer_ca_dir/cp-ca.key" \
    --not-before "$NOT_BEFORE" \
    --not-after "$AS_NOT_AFTER" \
    "$subj_dir/as.json" \
    "$out_dir/chain.pem" \
    "$out_dir/cp-as.key"

  clean_node_crypto "$node_dir"
  generate_master_keys "$node_dir"

  copy_to_node "$out_dir/chain.pem" "$node_dir/config/crypto/as/ISD${isd}-AS${asnum}.pem"
  copy_to_node "$out_dir/cp-as.key" "$node_dir/config/crypto/as/cp-as.key"
  copy_to_node "$issuer_root_dir/cp-root.pem" "$node_dir/config/crypto/ca/cp-root.pem"
  copy_to_node "$issuer_ca_dir/cp-ca.pem" "$node_dir/config/crypto/ca/cp-ca.pem"
}

rm -rf "$PKI_DIR"
mkdir -p "$PKI_DIR"
ensure_dir "$SCENARIO_DIR/scripts"

write_time_env
# shellcheck disable=SC1090
source "$TIME_ENV"

for core in "${CORE_AS[@]}"; do
  generate_core_bundle "$core"
done

for leaf in "${LEAF_AS[@]}"; do
  generate_leaf_as_cert "$leaf"
done

echo "PKI regenerada en: $PKI_DIR"
echo "Ventana temporal guardada en: $TIME_ENV"

