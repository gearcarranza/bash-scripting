#!/usr/bin/env bash
# 
# restart_thehive.sh
# Reinicia Cassandra, Minio, Elasticsearch y TheHive en el orden adecuado.
# Uso: sudo ./restart_thehive.sh
set -euo pipefail
IFS=$'\n\t'

# Servicios a parar en orden inverso de dependencia
SERVICES_STOP=(thehive elasticsearch minio cassandra)

# Servicios a iniciar en orden de dependencia
SERVICES_START=(cassandra minio elasticsearch thehive)
LOGFILE="/var/log/restart_thehive.log"

echo "=== $(date '+%F %T') | Inicio de reinicio de TheHive stack ===" | tee -a "$LOGFILE"

# Función especial solo para TheHive
function force_kill_thehive {
    local svc="thehive"
    echo "--- $(date '+%F %T') | Deteniendo $svc con timeout 120s" | tee -a "$LOGFILE"

    if ! timeout 120 systemctl stop "$svc"; then
        echo "    !! $svc no respondió en 120s, forzando kill -9..." | tee -a "$LOGFILE"
    fi

    if pgrep -f "$svc" >/dev/null; then
        local pids
        pids=$(pgrep -f "$svc")
        echo "    -> Procesos de $svc aún vivos: $pids" | tee -a "$LOGFILE"
        for pid in $pids; do
            kill -9 "$pid" && echo "    -> kill -9 $pid ejecutado" | tee -a "$LOGFILE"
        done
    fi
}

# Función general para acciones systemctl
function svc_action {
    local action=$1; shift
    for svc in "$@"; do
        echo "--- $(date '+%F %T') | systemctl $action $svc" | tee -a "$LOGFILE"

        if [[ "$action" == "stop" && "$svc" == "thehive" ]]; then
            # Solo thehive usa lógica especial
            force_kill_thehive
        else
            systemctl "$action" "$svc"
        fi

        if systemctl is-active --quiet "$svc"; then
            echo "    -> $svc is now $(systemctl is-active $svc)" | tee -a "$LOGFILE"
        else
            echo "    !! Warning: $svc failed to $action" | tee -a "$LOGFILE"
        fi
    done
}

echo; echo "1) Deteniendo servicios (dependencias abajo-arriba)..."
svc_action stop "${SERVICES_STOP[@]}"

echo; echo "2) Verificando procesos colgados..."
if pgrep -f 'thehive|cassandra|minio|elasticsearch'; then
    echo "    !! Algunos procesos siguen vivos:" | tee -a "$LOGFILE"
    pgrep -fl 'thehive|cassandra|minio|elasticsearch' | tee -a "$LOGFILE"
else
    echo "    -> Ningún proceso colgado detectado"
fi

echo; echo "3) Iniciando servicios (dependencias arriba-abajo)..."
svc_action start "${SERVICES_START[@]}"

echo; echo "4) Estado final de todos los servicios:"
for svc in "${SERVICES_START[@]}"; do
    printf "   %-12s: %s\n" "$svc" "$(systemctl is-active "$svc")"
done | tee -a "$LOGFILE"

echo "=== $(date '+%F %T') | Reinicio completado ===" | tee -a "$LOGFILE"
