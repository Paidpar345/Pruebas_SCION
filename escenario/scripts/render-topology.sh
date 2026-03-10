#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/alonso/Escritorio/scion-orchestrator"
SCENARIO_DIR="/home/alonso/Escritorio/scion-orchestrator/escenario"

# =========================================================
# Inventario del escenario
# 4 ISD
# Cada ISD:
#   - 2 Core AS
#   - 3 Leaf AS
#   - 2 Hosts simples
# =========================================================

CORE_ORDER=(
  "1-110" "1-111"
  "2-210" "2-211"
  "3-310" "3-311"
  "4-410" "4-411"
)

LEAF_ORDER=(
  "1-112" "1-113" "1-114"
  "2-212" "2-213" "2-214"
  "3-312" "3-313" "3-314"
  "4-412" "4-413" "4-414"
)

HOST_KEYS=(
  "1A" "1B"
  "2A" "2B"
  "3A" "3B"
  "4A" "4B"
)

declare -A AS_IP
declare -A AS_DIR
declare -A AS_ROLE
declare -A ISD_CORE_A
declare -A ISD_CORE_B
declare -A ISD_LEAFS
declare -A HOST_DIR
declare -A HOST_ATTACH_AS
declare -A HOST_BOOTSTRAP_IP
declare -A CORE_PAIR_PORT
declare -A HOST_IP

# =========================================================
# Direccionamiento IP
# Red Docker única: 10.0.0.0/16
# Esquema:
#   ISD1 -> 10.0.1.x
#   ISD2 -> 10.0.2.x
#   ISD3 -> 10.0.3.x
#   ISD4 -> 10.0.4.x
# =========================================================

# ISD1
AS_IP["1-110"]="10.0.1.10"
AS_IP["1-111"]="10.0.1.11"
AS_IP["1-112"]="10.0.1.12"
AS_IP["1-113"]="10.0.1.13"
AS_IP["1-114"]="10.0.1.14"
HOST_IP["1A"]="10.0.1.20"
HOST_IP["1B"]="10.0.1.21"

# ISD2
AS_IP["2-210"]="10.0.2.10"
AS_IP["2-211"]="10.0.2.11"
AS_IP["2-212"]="10.0.2.12"
AS_IP["2-213"]="10.0.2.13"
AS_IP["2-214"]="10.0.2.14"
HOST_IP["2A"]="10.0.2.20"
HOST_IP["2B"]="10.0.2.21"

# ISD3
AS_IP["3-310"]="10.0.3.10"
AS_IP["3-311"]="10.0.3.11"
AS_IP["3-312"]="10.0.3.12"
AS_IP["3-313"]="10.0.3.13"
AS_IP["3-314"]="10.0.3.14"
HOST_IP["3A"]="10.0.3.20"
HOST_IP["3B"]="10.0.3.21"

# ISD4
AS_IP["4-410"]="10.0.4.10"
AS_IP["4-411"]="10.0.4.11"
AS_IP["4-412"]="10.0.4.12"
AS_IP["4-413"]="10.0.4.13"
AS_IP["4-414"]="10.0.4.14"
HOST_IP["4A"]="10.0.4.20"
HOST_IP["4B"]="10.0.4.21"

for asid in "${CORE_ORDER[@]}" "${LEAF_ORDER[@]}"; do
  isd="${asid%%-*}"
  asnum="${asid#*-}"
  AS_DIR["$asid"]="$SCENARIO_DIR/ISD${isd}/AS${asnum}"
done

for asid in "${CORE_ORDER[@]}"; do AS_ROLE["$asid"]="core"; done
for asid in "${LEAF_ORDER[@]}"; do AS_ROLE["$asid"]="leaf"; done

ISD_CORE_A["1"]="1-110"
ISD_CORE_B["1"]="1-111"
ISD_CORE_A["2"]="2-210"
ISD_CORE_B["2"]="2-211"
ISD_CORE_A["3"]="3-310"
ISD_CORE_B["3"]="3-311"
ISD_CORE_A["4"]="4-410"
ISD_CORE_B["4"]="4-411"

ISD_LEAFS["1"]="1-112 1-113 1-114"
ISD_LEAFS["2"]="2-212 2-213 2-214"
ISD_LEAFS["3"]="3-312 3-313 3-314"
ISD_LEAFS["4"]="4-412 4-413 4-414"

HOST_DIR["1A"]="$SCENARIO_DIR/ISD1/HostA"
HOST_DIR["1B"]="$SCENARIO_DIR/ISD1/HostB"
HOST_DIR["2A"]="$SCENARIO_DIR/ISD2/HostA"
HOST_DIR["2B"]="$SCENARIO_DIR/ISD2/HostB"
HOST_DIR["3A"]="$SCENARIO_DIR/ISD3/HostA"
HOST_DIR["3B"]="$SCENARIO_DIR/ISD3/HostB"
HOST_DIR["4A"]="$SCENARIO_DIR/ISD4/HostA"
HOST_DIR["4B"]="$SCENARIO_DIR/ISD4/HostB"

HOST_ATTACH_AS["1A"]="1-110"
HOST_ATTACH_AS["1B"]="1-111"
HOST_ATTACH_AS["2A"]="2-210"
HOST_ATTACH_AS["2B"]="2-211"
HOST_ATTACH_AS["3A"]="3-310"
HOST_ATTACH_AS["3B"]="3-311"
HOST_ATTACH_AS["4A"]="4-410"
HOST_ATTACH_AS["4B"]="4-411"

HOST_BOOTSTRAP_IP["1A"]="${AS_IP["1-110"]}"
HOST_BOOTSTRAP_IP["1B"]="${AS_IP["1-111"]}"
HOST_BOOTSTRAP_IP["2A"]="${AS_IP["2-210"]}"
HOST_BOOTSTRAP_IP["2B"]="${AS_IP["2-211"]}"
HOST_BOOTSTRAP_IP["3A"]="${AS_IP["3-310"]}"
HOST_BOOTSTRAP_IP["3B"]="${AS_IP["3-311"]}"
HOST_BOOTSTRAP_IP["4A"]="${AS_IP["4-410"]}"
HOST_BOOTSTRAP_IP["4B"]="${AS_IP["4-411"]}"

# =========================================================
# Helpers
# =========================================================

mkconfig() {
  mkdir -p "$1/config"
}

ensure_runtime_links() {
  local node_dir="$1"

  ln -sfn ../../bin "$node_dir/bin"
  ln -sfn ../../scion-orchestrator "$node_dir/scion-orchestrator"

  cat > "$node_dir/run.sh" <<'EOF'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
export PATH="$PWD/bin:$PATH"
./scion-orchestrator run
EOF
  chmod +x "$node_dir/run.sh"
}


ensure_core_support_dirs() {
  local node_dir="$1"
  mkdir -p "$node_dir/config/certs"
  mkdir -p "$node_dir/config/crypto"
  mkdir -p "$node_dir/config/keys"

  if [[ ! -f "$node_dir/config/client1.secret" ]]; then
    head -c 32 /dev/urandom | base64 > "$node_dir/config/client1.secret"
  fi
}

ensure_leaf_support_dirs() {
  local node_dir="$1"
  mkdir -p "$node_dir/config/certs"
  mkdir -p "$node_dir/config/crypto"
  mkdir -p "$node_dir/config/keys"
}

ensure_host_support_dirs() {
  local node_dir="$1"
  mkdir -p "$node_dir/config"
}

write_br_toml() {
  local f="$1"
  cat > "$f" <<'EOF'
[general]
config_dir = "{configDir}"
id = "br-1"

[metrics]
prometheus = "127.0.0.1:30401"

[log.console]
level = "debug"
EOF
}

write_sciond_toml() {
  local f="$1"
  cat > "$f" <<'EOF'
[general]
id = "sd"
config_dir = "{configDir}"

[metrics]
prometheus = "127.0.0.1:30455"

[path_db]
connection = "{databaseDir}sd.path.db"

[trust_db]
connection = "{databaseDir}sd.trust.db"

[log.console]
level = "debug"
EOF
}

write_dispatcher_toml() {
  local f="$1"
  local isd_as="$2"
  cat > "$f" <<EOF
[dispatcher]
id = "dispatcher"
local_udp_forwarding = true
# socket_file_mode = "0777"

[metrics]
prometheus = "[127.0.0.1]:30441"

[log.console]
level = "debug"

# Support Single host ASes
[dispatcher.service_addresses]
"${isd_as},CS" = "127.0.0.1:30254"
"${isd_as},DS" = "127.0.0.1:30254"
EOF
}

write_trcs_json() {
  local f="$1"
  local isd="$2"
  cat > "$f" <<EOF
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

write_core_orchestrator_toml() {
  local f="$1"
  local isd_as="$2"
  local ip="$3"
  cat > "$f" <<EOF
command = "service"
isd_as = "${isd_as}"
mode = "as"

[metrics]
prometheus = "127.0.0.1:33401"

[bootstrap]
server = "${ip}:8041"
# allowedSubnets = [""] # TODO: Rethink this

[ca]
server = ":3000"
clients = ["123:client1.secret"] # Starts from configDir
EOF
}

write_leaf_orchestrator_toml() {
  local f="$1"
  local isd_as="$2"
  local bootstrap_ip="$3"
  cat > "$f" <<EOF
command = "service"
isd_as = "${isd_as}"
mode = "as"

[metrics]
prometheus = "127.0.0.1:33401"

[bootstrap]
server = "${bootstrap_ip}:8041"
# allowedSubnets = [""] # TODO: Rethink this
EOF
}

write_host_orchestrator_toml() {
  local f="$1"
  local attach_as="$2"
  local bootstrap_ip="$3"
  cat > "$f" <<EOF
command = "service"
isd_as = "${attach_as}"
mode = "endhost"

[metrics]
server = "127.0.0.1:33401"

[bootstrap]
server = "${bootstrap_ip}:8041"
# allowedSubnets = [""] # TODO: Rethink this
EOF
}

write_core_cs_toml() {
  local f="$1"
  local ip="$2"
  cat > "$f" <<EOF
[beacon_db]
connection = "{databaseDir}cs-1.beacon.db"

[beaconing]
origination_interval = "5s"
propagation_interval = "5s"

[general]
id = "cs-1"
config_dir = "{configDir}"

[metrics]
prometheus = "127.0.0.1:30454"

[path_db]
connection = "{databaseDir}cs-1.path.db"

[trust_db]
connection = "{databaseDir}cs-1.trust.db"

[log.console]
level = "debug"

[api]
addr = "${ip}:30554"

[ca]
mode = "delegating"

[ca.service]
shared_secret = "config/client1.secret"
addr = "http://127.0.0.1:3000"
client_id = "123"
EOF
}

write_leaf_cs_toml() {
  local f="$1"
  local ip="$2"
  cat > "$f" <<EOF
[beacon_db]
connection = "{databaseDir}cs-1.beacon.db"

[beaconing]
origination_interval = "5s"
propagation_interval = "5s"

[general]
id = "cs-1"
config_dir = "{configDir}"

[metrics]
prometheus = "127.0.0.1:30454"

[path_db]
connection = "{databaseDir}cs-1.path.db"

[trust_db]
connection = "{databaseDir}cs-1.trust.db"

[log.console]
level = "debug"

[api]
addr = "${ip}:30554"
EOF
}

leaf_index_in_isd() {
  local asid="$1"
  local asnum="${asid#*-}"
  case "${asnum: -1}" in
    2) echo 0 ;;
    3) echo 1 ;;
    4) echo 2 ;;
    *) echo "0" ;;
  esac
}

build_core_pair_ports() {
  local port=50000
  local i j a b key
  for ((i=0; i<${#CORE_ORDER[@]}; i++)); do
    for ((j=i+1; j<${#CORE_ORDER[@]}; j++)); do
      a="${CORE_ORDER[$i]}"
      b="${CORE_ORDER[$j]}"
      key="${a}|${b}"
      CORE_PAIR_PORT["$key"]="$port"
      port=$((port + 1))
    done
  done
}

core_pair_key() {
  local a="$1"
  local b="$2"
  local i_a=-1
  local i_b=-1
  local i
  for ((i=0; i<${#CORE_ORDER[@]}; i++)); do
    [[ "${CORE_ORDER[$i]}" == "$a" ]] && i_a="$i"
    [[ "${CORE_ORDER[$i]}" == "$b" ]] && i_b="$i"
  done
  if (( i_a < i_b )); then
    echo "${a}|${b}"
  else
    echo "${b}|${a}"
  fi
}

leaf_link_port() {
  local isd="$1"
  local leaf_idx="$2"   # 0,1,2
  local core_idx="$3"   # 0,1
  echo $((51000 + isd*100 + leaf_idx*10 + core_idx))
}

write_core_topology_json() {
  local f="$1"
  local asid="$2"
  local isd="${asid%%-*}"
  local ip="${AS_IP[$asid]}"
  local tmp="${f}.tmp"
  local ifid=1
  local first=1
  local peer peer_ip key port
  local leaf leaf_ip leaf_idx core_idx

  : > "$tmp"
  cat >> "$tmp" <<EOF
{
  "attributes": [
    "authoritative",
    "issuing",
    "voting",
    "core"
  ],
  "isd_as": "${asid}",
  "mtu": 1500,
  "control_service": {
    "cs-1": {
      "addr": "${ip}:30254"
    }
  },
  "discovery_service": {
    "cs-1": {
      "addr": "${ip}:30254"
    }
  },
  "border_routers": {
    "br-1": {
      "internal_addr": "${ip}:30001",
      "interfaces": {
EOF

  for peer in "${CORE_ORDER[@]}"; do
    [[ "$peer" == "$asid" ]] && continue
    peer_ip="${AS_IP[$peer]}"
    key="$(core_pair_key "$asid" "$peer")"
    port="${CORE_PAIR_PORT[$key]}"

    if (( first == 0 )); then
      echo "," >> "$tmp"
    fi
    first=0

    cat >> "$tmp" <<EOF
        "${ifid}": {
          "underlay": {
            "public": "${ip}:${port}",
            "remote": "${peer_ip}:${port}"
          },
          "isd_as": "${peer}",
          "link_to": "CORE",
          "mtu": 1500
        }
EOF
    ifid=$((ifid + 1))
  done

  core_idx=0
  [[ "$asid" == "${ISD_CORE_B[$isd]}" ]] && core_idx=1

  for leaf in ${ISD_LEAFS[$isd]}; do
    leaf_ip="${AS_IP[$leaf]}"
    leaf_idx="$(leaf_index_in_isd "$leaf")"
    port="$(leaf_link_port "$isd" "$leaf_idx" "$core_idx")"

    if (( first == 0 )); then
      echo "," >> "$tmp"
    fi
    first=0

    cat >> "$tmp" <<EOF
        "${ifid}": {
          "underlay": {
            "public": "${ip}:${port}",
            "remote": "${leaf_ip}:${port}"
          },
          "isd_as": "${leaf}",
          "link_to": "CHILD",
          "mtu": 1500
        }
EOF
    ifid=$((ifid + 1))
  done

  cat >> "$tmp" <<EOF

      }
    }
  },
  "dispatched_ports": "30000-32767"
}
EOF

  mv "$tmp" "$f"
}

write_leaf_topology_json() {
  local f="$1"
  local asid="$2"
  local isd="${asid%%-*}"
  local ip="${AS_IP[$asid]}"
  local tmp="${f}.tmp"
  local leaf_idx
  local core_a core_b ip_a ip_b port_a port_b

  core_a="${ISD_CORE_A[$isd]}"
  core_b="${ISD_CORE_B[$isd]}"
  ip_a="${AS_IP[$core_a]}"
  ip_b="${AS_IP[$core_b]}"
  leaf_idx="$(leaf_index_in_isd "$asid")"
  port_a="$(leaf_link_port "$isd" "$leaf_idx" 0)"
  port_b="$(leaf_link_port "$isd" "$leaf_idx" 1)"

  cat > "$tmp" <<EOF
{
  "attributes": [],
  "isd_as": "${asid}",
  "mtu": 1500,
  "control_service": {
    "cs-1": {
      "addr": "${ip}:30254"
    }
  },
  "discovery_service": {
    "cs-1": {
      "addr": "${ip}:30254"
    }
  },
  "border_routers": {
    "br-1": {
      "internal_addr": "${ip}:30001",
      "interfaces": {
        "1": {
          "underlay": {
            "public": "${ip}:${port_a}",
            "remote": "${ip_a}:${port_a}"
          },
          "isd_as": "${core_a}",
          "link_to": "PARENT",
          "mtu": 1500
        },
        "2": {
          "underlay": {
            "public": "${ip}:${port_b}",
            "remote": "${ip_b}:${port_b}"
          },
          "isd_as": "${core_b}",
          "link_to": "PARENT",
          "mtu": 1500
        }
      }
    }
  },
  "dispatched_ports": "30000-32767"
}
EOF

  mv "$tmp" "$f"
}

render_core_as() {
  local asid="$1"
  local node_dir="${AS_DIR[$asid]}"
  local ip="${AS_IP[$asid]}"
  local isd="${asid%%-*}"

  mkconfig "$node_dir"
  ensure_runtime_links "$node_dir"
  ensure_core_support_dirs "$node_dir"

  write_core_orchestrator_toml "$node_dir/config/scion-orchestrator.toml" "$asid" "$ip"
  write_core_cs_toml "$node_dir/config/cs-1.toml" "$ip"
  write_br_toml "$node_dir/config/br-1.toml"
  write_dispatcher_toml "$node_dir/config/dispatcher.toml" "$asid"
  write_sciond_toml "$node_dir/config/sciond.toml"
  write_trcs_json "$node_dir/config/trcs.json" "$isd"
  write_core_topology_json "$node_dir/config/topology.json" "$asid"
}

render_leaf_as() {
  local asid="$1"
  local node_dir="${AS_DIR[$asid]}"
  local ip="${AS_IP[$asid]}"
  local isd="${asid%%-*}"
  local bootstrap_ip="${AS_IP[${ISD_CORE_A[$isd]}]}"

  mkconfig "$node_dir"
  ensure_runtime_links "$node_dir"
  ensure_leaf_support_dirs "$node_dir"

  write_leaf_orchestrator_toml "$node_dir/config/scion-orchestrator.toml" "$asid" "$bootstrap_ip"
  write_leaf_cs_toml "$node_dir/config/cs-1.toml" "$ip"
  write_br_toml "$node_dir/config/br-1.toml"
  write_dispatcher_toml "$node_dir/config/dispatcher.toml" "$asid"
  write_sciond_toml "$node_dir/config/sciond.toml"
  write_trcs_json "$node_dir/config/trcs.json" "$isd"
  write_leaf_topology_json "$node_dir/config/topology.json" "$asid"
}

render_host() {
  local hkey="$1"
  local node_dir="${HOST_DIR[$hkey]}"
  local attach_as="${HOST_ATTACH_AS[$hkey]}"
  local bootstrap_ip="${HOST_BOOTSTRAP_IP[$hkey]}"

  ensure_host_support_dirs "$node_dir"
  ensure_runtime_links "$node_dir"

  write_host_orchestrator_toml "$node_dir/config/scion-orchestrator.toml" "$attach_as" "$bootstrap_ip"
  write_sciond_toml "$node_dir/config/sciond.toml"
}

service_name_from_node_dir() {
  local path="$1"
  local rel="${path#$SCENARIO_DIR/}"
  echo "${rel//\//_}" | tr '[:upper:]' '[:lower:]'
}

write_compose_service() {
  local compose_file="$1"
  local node_dir="$2"
  local service_name="$3"
  local container_name="$4"
  local ip="$5"

  cat >> "$compose_file" <<EOF
  ${service_name}:
    image: ubuntu:22.10
    container_name: ${container_name}
    command: [ "bash", "-lc", "cd /root/escenario/${node_dir#$SCENARIO_DIR/} && ./run.sh" ]
    cap_add:
      - ALL
    privileged: true
    volumes:
      - "${SCENARIO_DIR}:/root/escenario"
    networks:
      scion_net:
        ipv4_address: ${ip}

EOF
}

generate_docker_compose() {
  local f="$SCENARIO_DIR/docker-compose.yml"
  : > "$f"

  cat >> "$f" <<'EOF'
version: "3.4"
services:
EOF

  local asid node_dir service_name container_name ip
  for asid in "${CORE_ORDER[@]}" "${LEAF_ORDER[@]}"; do
    node_dir="${AS_DIR[$asid]}"
    service_name="$(service_name_from_node_dir "$node_dir")"
    container_name="${service_name}"
    ip="${AS_IP[$asid]}"
    write_compose_service "$f" "$node_dir" "$service_name" "$container_name" "$ip"
  done

  local hkey
  for hkey in "${HOST_KEYS[@]}"; do
    node_dir="${HOST_DIR[$hkey]}"
    service_name="$(service_name_from_node_dir "$node_dir")"
    container_name="${service_name}"
    ip="${HOST_IP[$hkey]}"
    write_compose_service "$f" "$node_dir" "$service_name" "$container_name" "$ip"
  done

  cat >> "$f" <<'EOF'
networks:
  scion_net:
    driver_opts:
      com.docker.network.driver.mtu: 1500
    ipam:
      config:
        - subnet: 10.0.0.0/16
EOF
}

# =========================================================
# Main
# =========================================================

build_core_pair_ports

for asid in "${CORE_ORDER[@]}"; do
  render_core_as "$asid"
done

for asid in "${LEAF_ORDER[@]}"; do
  render_leaf_as "$asid"
done

for hkey in "${HOST_KEYS[@]}"; do
  render_host "$hkey"
done

generate_docker_compose

echo "Render completado."
echo "Escenario generado en: $SCENARIO_DIR"
echo "Docker compose generado en: $SCENARIO_DIR/docker-compose.yml"
