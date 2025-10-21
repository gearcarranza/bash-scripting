# Escaner de IPs
#!/bin/bash

# Script para escanear IPs activas e inactivas en el segmento de red local
# Autor: Script generado para escaneo de red
# Uso: ./scan_network.sh

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Escáner de Red - Segmento Local${NC}"
echo -e "${BLUE}=================================================${NC}\n"

# Obtener la IP y máscara de red de la interfaz principal
get_network_info() {
    # Obtener la interfaz de red principal (excluyendo loopback)
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}Error: No se pudo detectar la interfaz de red${NC}"
        exit 1
    fi
    
    # Obtener IP y máscara de la interfaz
    IP_INFO=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}')
    
    if [ -z "$IP_INFO" ]; then
        echo -e "${RED}Error: No se pudo obtener la información de IP${NC}"
        exit 1
    fi
    
    # Extraer IP y CIDR
    MY_IP=$(echo "$IP_INFO" | cut -d'/' -f1)
    CIDR=$(echo "$IP_INFO" | cut -d'/' -f2)
    
    # Calcular la red base
    IFS=. read -r i1 i2 i3 i4 <<< "$MY_IP"
    
    # Calcular máscara según CIDR (común: /24)
    if [ "$CIDR" -eq 24 ]; then
        NETWORK="${i1}.${i2}.${i3}.0"
        BROADCAST="${i1}.${i2}.${i3}.255"
        RANGE="${i1}.${i2}.${i3}"
        START=1
        END=254
    elif [ "$CIDR" -eq 16 ]; then
        NETWORK="${i1}.${i2}.0.0"
        BROADCAST="${i1}.${i2}.255.255"
        echo -e "${YELLOW}Advertencia: Red /16 detectada. Esto puede tomar mucho tiempo.${NC}"
        echo -e "${YELLOW}Se escaneará solo la subred /24 actual: ${i1}.${i2}.${i3}.0/24${NC}\n"
        RANGE="${i1}.${i2}.${i3}"
        START=1
        END=254
    else
        RANGE="${i1}.${i2}.${i3}"
        START=1
        END=254
    fi
}

# Función para hacer ping a una IP
check_ip() {
    local ip=$1
    # Ping con timeout de 1 segundo y 1 solo paquete
    if ping -c 1 -W 1 "$ip" &> /dev/null; then
        echo "ACTIVE:$ip"
    else
        echo "INACTIVE:$ip"
    fi
}

# Obtener información de la red
get_network_info

echo -e "${YELLOW}Información de Red:${NC}"
echo -e "  Interfaz: ${GREEN}$INTERFACE${NC}"
echo -e "  Tu IP: ${GREEN}$MY_IP${NC}"
echo -e "  Segmento: ${GREEN}$RANGE.0/$CIDR${NC}"
echo -e "  Rango a escanear: ${GREEN}$RANGE.$START - $RANGE.$END${NC}\n"

echo -e "${BLUE}Iniciando escaneo...${NC}"
echo -e "${YELLOW}Esto puede tomar unos minutos dependiendo del tamaño de la red${NC}\n"

# Arrays para almacenar resultados
declare -a ACTIVE_IPS
declare -a INACTIVE_IPS

# Contador de progreso
TOTAL=$((END - START + 1))
CURRENT=0

# Escanear todas las IPs en el rango
for i in $(seq $START $END); do
    IP="$RANGE.$i"
    CURRENT=$((CURRENT + 1))
    
    # Mostrar progreso cada 10 IPs
    if [ $((CURRENT % 10)) -eq 0 ]; then
        PERCENT=$((CURRENT * 100 / TOTAL))
        echo -ne "${YELLOW}Progreso: $PERCENT% ($CURRENT/$TOTAL)${NC}\r"
    fi
    
    # Realizar ping y capturar resultado
    RESULT=$(check_ip "$IP")
    
    if [[ $RESULT == ACTIVE:* ]]; then
        ACTIVE_IPS+=("${RESULT#ACTIVE:}")
    else
        INACTIVE_IPS+=("${RESULT#INACTIVE:}")
    fi
done

echo -e "\n"
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}           Resultados del Escaneo${NC}"
echo -e "${BLUE}=================================================${NC}\n"

# Mostrar IPs activas
echo -e "${GREEN}[+] IPs ACTIVAS (${#ACTIVE_IPS[@]}):${NC}"
for ip in "${ACTIVE_IPS[@]}"; do
    if [ "$ip" == "$MY_IP" ]; then
        echo -e "  ${GREEN}✓ $ip ${YELLOW}(Esta máquina)${NC}"
    else
        echo -e "  ${GREEN}✓ $ip${NC}"
    fi
done

echo -e "\n${RED}[-] IPs INACTIVAS (${#INACTIVE_IPS[@]}):${NC}"
# Mostrar solo las primeras 20 IPs inactivas para no saturar
if [ ${#INACTIVE_IPS[@]} -gt 20 ]; then
    for i in {0..19}; do
        echo -e "  ${RED}✗ ${INACTIVE_IPS[$i]}${NC}"
    done
    echo -e "  ${YELLOW}... y $((${#INACTIVE_IPS[@]} - 20)) más${NC}"
else
    for ip in "${INACTIVE_IPS[@]}"; do
        echo -e "  ${RED}✗ $ip${NC}"
    done
fi

# Resumen
echo -e "\n${BLUE}=================================================${NC}"
echo -e "${YELLOW}Resumen:${NC}"
echo -e "  Total escaneadas: ${BLUE}$TOTAL${NC}"
echo -e "  Activas: ${GREEN}${#ACTIVE_IPS[@]}${NC}"
echo -e "  Inactivas: ${RED}${#INACTIVE_IPS[@]}${NC}"
echo -e "${BLUE}=================================================${NC}"

# Opción para exportar resultados
echo -e "\n${YELLOW}¿Deseas guardar los resultados? (s/n)${NC}"
read -r SAVE

if [[ $SAVE =~ ^[Ss]$ ]]; then
    FILENAME="scan_result_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "Escaneo de Red - $(date)"
        echo "Segmento: $RANGE.0/$CIDR"
        echo "=========================================="
        echo ""
        echo "IPs ACTIVAS (${#ACTIVE_IPS[@]}):"
        printf '%s\n' "${ACTIVE_IPS[@]}"
        echo ""
        echo "IPs INACTIVAS (${#INACTIVE_IPS[@]}):"
        printf '%s\n' "${INACTIVE_IPS[@]}"
    } > "$FILENAME"
    echo -e "${GREEN}Resultados guardados en: $FILENAME${NC}"
fi

echo -e "\n${GREEN}Escaneo completado!${NC}"