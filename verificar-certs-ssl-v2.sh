
#!/bin/bash

# Pool de IPs/dominios a verificar
# Puedes agregar o quitar IPs según necesites
POOL_IPS=(
    "135.208.38.149"
    "135.208.38.150"
    # Agrega más IPs o dominios aquí
)

# Colores para mejor visualización (opcional)
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Función para verificar certificado SSL
check_ssl_certificate() {
    local host=$1
    
    echo "=========================================="
    echo "Verificando: $host"
    echo "=========================================="
    
    # Intentar obtener la fecha de expiración del certificado
    data=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | sed -e 's#notAfter=##')
    
    # Verificar si se pudo obtener el certificado
    if [ -z "$data" ]; then
        echo -e "${RED}ERROR: No se pudo obtener el certificado SSL para $host${NC}"
        echo -e "${RED}Posibles causas: Host inaccesible, sin certificado SSL, o puerto 443 cerrado${NC}"
        echo ""
        return 1
    fi
    
    # Calcular días restantes
    ssldate=$(date -d "${data}" '+%s' 2>/dev/null)
    
    # Verificar si la fecha es válida
    if [ -z "$ssldate" ]; then
        echo -e "${RED}ERROR: No se pudo procesar la fecha del certificado${NC}"
        echo ""
        return 1
    fi
    
    nowdate=$(date '+%s')
    diff=$((ssldate - nowdate))
    total=$((diff / 86400))
    
    # Mostrar resultado con colores según días restantes
    if [ $total -lt 0 ]; then
        echo -e "${RED}⚠ CERTIFICADO EXPIRADO hace $((-total)) días para: $host${NC}"
    elif [ $total -lt 30 ]; then
        echo -e "${RED}⚠ CRITICO: Quedan solo $total días para que el certificado caduque en: $host${NC}"
    elif [ $total -lt 60 ]; then
        echo -e "${YELLOW}⚠ ADVERTENCIA: Quedan $total días para que el certificado caduque en: $host${NC}"
    else
        echo -e "${GREEN}✓ Queda un total de $total días para que el certificado caduque en: $host${NC}"
    fi
    
    echo "Fecha de expiración: $data"
    echo ""
}

# Función principal
main() {
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     VERIFICADOR DE CERTIFICADOS SSL - v2.0             ║"
    echo "║     Total de hosts a verificar: ${#POOL_IPS[@]}                      ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Contador de estadísticas
    local total_hosts=${#POOL_IPS[@]}
    local successful=0
    local failed=0
    local expired=0
    local critical=0
    
    # Iterar sobre todas las IPs del pool
    for ip in "${POOL_IPS[@]}"; do
        check_ssl_certificate "$ip"
        status=$?
        
        if [ $status -eq 0 ]; then
            ((successful++))
        else
            ((failed++))
        fi
    done
    
    # Resumen final
    echo "=========================================="
    echo "           RESUMEN DE VERIFICACIÓN"
    echo "=========================================="
    echo "Total de hosts verificados: $total_hosts"
    echo -e "${GREEN}Certificados válidos verificados: $successful${NC}"
    echo -e "${RED}Hosts con errores: $failed${NC}"
    echo "=========================================="
}

# Ejecutar script
main