#!/bin/bash
# oracle_rac19c_full_precheck.sh
# Script unificado de validación RAC 19c en RHEL8
# Genera salida en archivo .txt para ingestión por Zabbix (trapper items)


OUTPUT="/var/log/oracle_rac19c_precheck.txt"
NODO_LOCAL=$(hostname)
NODO_REMOTO="rac2"    # Cambiar al nombre del nodo par
DATE=$(date '+%Y-%m-%d %H:%M:%S')

exec > $OUTPUT 2>&1

echo "======================================"
echo " Oracle RAC 19c - Precheck Completo (RHEL8)"
echo " Nodo local:   $NODO_LOCAL"
echo " Nodo remoto:  $NODO_REMOTO"
echo " Fecha:        $DATE"
echo "======================================"

# Función para ejecutar en nodo remoto
remote_exec() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 $NODO_REMOTO "$1"
}

# 1. OS y Kernel
echo -e "\n[OS]"
local_os=$(cat /etc/redhat-release)
remote_os=$(remote_exec "cat /etc/redhat-release")
echo "os_local=$local_os"
echo "os_remoto=$remote_os"

local_kernel=$(uname -r)
remote_kernel=$(remote_exec "uname -r")
echo "kernel_local=$local_kernel"
echo "kernel_remoto=$remote_kernel"

# 2. Paquetes requeridos (RHEL8)
echo -e "\n[PACKAGES]"
PKGS="bc binutils compat-openssl10 \
elfutils-libelf elfutils-libelf-devel fontconfig-devel \
glibc glibc-devel ksh libaio libaio-devel libX11 \
libXau libXi libXtst libXrender libXrender-devel \
libgcc libnsl libnsl.i686 libstdc++ libstdc++-devel \
libxcb make smartmontools sysstat"

for p in $PKGS; do
    rpm -q $p &>/dev/null && echo "pkg_${p}_local=OK" || echo "pkg_${p}_local=MISSING"
    remote_exec "rpm -q $p &>/dev/null" && echo "pkg_${p}_remoto=OK" || echo "pkg_${p}_remoto=MISSING"
done

# 3. Kernel params
echo -e "\n[KERNEL_PARAMS]"
params="fs.file-max kernel.sem kernel.shmmax kernel.shmall net.core.rmem_max net.core.wmem_max"
for prm in $params; do
    lv=$(sysctl -n $prm 2>/dev/null || echo "N/A")
    rv=$(remote_exec "sysctl -n $prm 2>/dev/null || echo 'N/A'")
    echo "param_${prm}_local=$lv"
    echo "param_${prm}_remoto=$rv"
done

# 4. Usuarios y grupos
echo -e "\n[USERS]"
for u in grid oracle; do
    id $u >/dev/null 2>&1 && echo "user_${u}_local=OK" || echo "user_${u}_local=MISSING"
    remote_exec "id $u >/dev/null 2>&1" && echo "user_${u}_remoto=OK" || echo "user_${u}_remoto=MISSING"
done

# 5. Red
echo -e "\n[NETWORK]"
for h in rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan; do
    lh=$(getent hosts $h | awk '{print $1}')
    rh=$(remote_exec "getent hosts $h | awk '{print \$1}'")
    echo "net_${h}_local=${lh:-UNRESOLVED}"
    echo "net_${h}_remoto=${rh:-UNRESOLVED}"
done

# 6. Discos ASM
echo -e "\n[ASM_DISKS]"
local_disks=$(lsblk -ndo NAME,SIZE,TYPE | grep disk | awk '{print $1":"$2}' | tr '\n' ',')
remote_disks=$(remote_exec "lsblk -ndo NAME,SIZE,TYPE | grep disk | awk '{print \$1\":\"\$2}' | tr '\n' ','")
echo "asm_disks_local=${local_disks%,}"
echo "asm_disks_remoto=${remote_disks%,}"

# 7. Resumen para Zabbix
echo -e "\n[SUMMARY]"
echo "precheck_status=COMPLETED"
echo "timestamp=$DATE"

echo "======================================"
echo " Precheck completado. Resultados en: $OUTPUT"
echo "======================================"
