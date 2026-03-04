#!/bin/bash

echo "Generando los 28 archivos scion-orchestrator.toml..."

# 1. ASES CORE VOTING (Servidor CA + Bootstrap)
for ISD in 1 2 3 4; do
  AS_NUM="${ISD}10"
  
  cat > topo/isd${ISD}-as${AS_NUM}/scion-orchestrator.toml << EOF
isd_as = "${ISD}-${AS_NUM}"
mode   = "as"

[ca]
server  = "0.0.0.0:3000"
# Lista de clientes (resto de ASes del ISD) con sus respectivos secretos
clients = ["${ISD}20:secrets/secret-${ISD}20.txt",
           "${ISD}30:secrets/secret-${ISD}30.txt",
           "${ISD}40:secrets/secret-${ISD}40.txt",
           "${ISD}50:secrets/secret-${ISD}50.txt"]

[metrics]
server = "0.0.0.0:33400"

[bootstrap]
# El servidor bootstrap se activa implícitamente en el puerto 8041
EOF
done

# 2. ASES CORE NO-VOTING Y LEAFS (Delegación CA)
for ISD in 1 2 3 4; do
  CA_IP="172.20.${ISD}.10" # La IP del Core Voting de este ISD
  
  for SUFFIX in 20 30 40 50; do
    AS_NUM="${ISD}${SUFFIX}"
    
    cat > topo/isd${ISD}-as${AS_NUM}/scion-orchestrator.toml << EOF
isd_as = "${ISD}-${AS_NUM}"
mode   = "as"

[ca.service]
mode          = "delegating"
shared_secret = "secrets/secret-${AS_NUM}.txt"
addr          = "http://${CA_IP}:3000"
client_id     = "${AS_NUM}"

[metrics]
server = "0.0.0.0:33400"
EOF
  done
done

# 3. ENDHOSTS (2 por ISD)
for ISD in 1 2 3 4; do
  BOOTSTRAP_IP="172.20.${ISD}.10" # Apuntan al bootstrap del Core Voting
  
  for HOST in 1 2; do
    cat > topo/host${HOST}-isd${ISD}/scion-orchestrator.toml << EOF
isd_as = "${ISD}-${ISD}10"
mode   = "endhost"

[bootstrap]
server = "${BOOTSTRAP_IP}:8041"

[metrics]
server = "0.0.0.0:33400"
EOF
  done
done

echo "✓ 28 archivos scion-orchestrator.toml generados con éxito."
