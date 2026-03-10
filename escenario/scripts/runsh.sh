#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/alonso/Escritorio/scion-orchestrator/escenario"

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

for node_dir in "$SCENARIO_DIR"/ISD*/*; do
  fix_node "$node_dir"
done

echo "Todos los run.sh han sido actualizados."

