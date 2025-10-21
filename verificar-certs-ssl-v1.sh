#!/bin/bash
# Creado por Gerardo Arévalo Carranza
# Logicalis México
# Octubre del 2025

data=$(echo | openssl s_client -servername $1 -connect $1:443 2>/dev/null | openssl x509 -noout -enddate | sed -e 's#notAfter=##')

ssldate=$(date -d "${data}" '+%s')
nowdate=$(date '+%s')
diff="$((${ssldate}-${nowdate}))"
total=$((${diff}/86400))

echo "Queda un total de "${total}" días para que el certificado caduque en la dirección IP: "${1}
