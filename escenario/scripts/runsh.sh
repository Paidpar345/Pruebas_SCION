#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_repo_root() {
  local d="$SCRIPT_DIR"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/escenario" && ( -d "$d/bin" || -x "$d/scion-orchestrator" ) ]]; then
      echo "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

REPO_ROOT="${REPO_ROOT:-$(resolve_repo_root || true)}"

if [[ -z "${REPO_ROOT:-}" ]]; then
  echo "ERROR: no pude resolver REPO_ROOT automáticamente"
  echo "Exporta REPO_ROOT manualmente, por ejemplo:"
  echo "  export REPO_ROOT=\"$HOME/Escritorio/scion-orchestrator\""
  exit 1
fi

SCENARIO_DIR="${SCENARIO_DIR:-$REPO_ROOT/escenario}"
BIN_DIR="${BIN_DIR:-$REPO_ROOT/bin}"
ORCHESTRATOR_BIN="${ORCHESTRATOR_BIN:-$REPO_ROOT/scion-orchestrator}"

sync_runtime_assets() {
  mkdir -p "$SCENARIO_DIR/bin"
  [[ -d "$BIN_DIR" ]] || { echo "ERROR: no existe BIN_DIR=$BIN_DIR"; exit 1; }
  [[ -x "$ORCHESTRATOR_BIN" ]] || { echo "ERROR: no existe ORCHESTRATOR_BIN=$ORCHESTRATOR_BIN"; exit 1; }

  find "$BIN_DIR" -maxdepth 1 -type f -exec cp -f {} "$SCENARIO_DIR/bin/" \;
  chmod 755 "$SCENARIO_DIR"/bin/* 2>/dev/null || true
  cp -f "$ORCHESTRATOR_BIN" "$SCENARIO_DIR/scion-orchestrator"
  chmod 755 "$SCENARIO_DIR/scion-orchestrator"
}

write_host_runsh() {
  local node_dir="$1"

  cat > "$node_dir/run.sh" <<'EOF'
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
EOF
  chmod +x "$node_dir/run.sh"
}

write_as_runsh() {
  local node_dir="$1"

  cat > "$node_dir/run.sh" <<'EOF'
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
EOF
  chmod +x "$node_dir/run.sh"
}

fix_node() {
  local node_dir="$1"
  local node_name

  [[ ! -d "$node_dir" ]] && return 0
  [[ ! -d "$node_dir/config" ]] && return 0

  node_name="$(basename "$node_dir")"

  ln -sfn ../../bin "$node_dir/bin"
  ln -sfn ../../scion-orchestrator "$node_dir/scion-orchestrator"
  mkdir -p "$node_dir/config/certs"

  if [[ "$node_name" == Host* ]]; then
    write_host_runsh "$node_dir"
    echo "run.sh de HOST corregido en: $node_dir"
  else
    write_as_runsh "$node_dir"
    echo "run.sh de AS corregido en: $node_dir"
  fi
}

sync_runtime_assets

for node_dir in "$SCENARIO_DIR"/ISD*/*; do
  fix_node "$node_dir"
done

echo "Todos los run.sh han sido actualizados."

