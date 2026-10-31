#!/usr/bin/env bash
# USE method -> JSON lines. Ejecutar cada 60s (systemd timer o cron).
LOG=${LOG:-/var/log/use_metrics.log}
INT=${INT:-5}                       # ventana de muestreo en segundos
HOST=$(hostname -s); NCPU=$(nproc)

cpu_snap(){ awk '/^cpu /{t=0; for(i=2;i<=9;i++)t+=$i; print t, $5+$6}' /proc/stat; }
disk_snap(){ awk '$3 ~ /^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|nvme[0-9]+n[0-9]+)$/ {print $3,$13,$14}' /proc/diskstats | sort; }
net_snap(){ for d in /sys/class/net/*; do [ "$(basename $d)" = lo ] && continue
  s=$d/statistics; echo "$(basename $d) $(cat $s/rx_bytes) $(cat $s/tx_bytes) \
$(( $(cat $s/rx_errors)+$(cat $s/tx_errors) )) $(( $(cat $s/rx_dropped)+$(cat $s/tx_dropped) ))"; done | sort; }
vm(){ awk -v k="$1" '$1==k{print $2}' /proc/vmstat; }
psi(){ awk '/^some/{split($2,a,"="); print a[2]}' /proc/pressure/$1 2>/dev/null || echo null; }

read T1 I1 <<< "$(cpu_snap)"; D1=$(disk_snap); N1=$(net_snap)
SW1=$(( $(vm pswpin)+$(vm pswpout) )); OOM1=$(vm oom_kill)
sleep "$INT"
read T2 I2 <<< "$(cpu_snap)"; D2=$(disk_snap); N2=$(net_snap)
SW2=$(( $(vm pswpin)+$(vm pswpout) )); OOM2=$(vm oom_kill)
TS=$(date -u +%FT%TZ)
emit(){ printf '{"ts":"%s","host":"%s","resource":"%s","util":%s,"sat":%s,"err":%s%s}\n' "$TS" "$HOST" "$@"; }

{
# CPU
U=$(awk -v t=$((T2-T1)) -v i=$((I2-I1)) 'BEGIN{printf "%.1f",100*(t-i)/t}')
RQ=$(awk '/procs_running/{print $2-1}' /proc/stat)
emit cpu "$U" "$RQ" null ",\"runq_per_cpu\":$(awk -v r=$RQ -v n=$NCPU 'BEGIN{printf "%.2f",r/n}'),\"psi_some_avg10\":$(psi cpu)"

# Memoria
U=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%.1f",100*(t-a)/t}' /proc/meminfo)
emit mem "$U" "$((SW2-SW1))" "$((OOM2-OOM1))" ",\"psi_some_avg10\":$(psi memory)"

# Disco (por device)
join <(echo "$D1") <(echo "$D2") | awk -v t=$INT '{printf "%s %.1f %.2f\n",$1,($4-$2)/(t*10),($5-$3)/(t*1000)}' |
while read dev util q; do emit disk "$util" "$q" null ",\"dev\":\"$dev\",\"psi_io_some_avg10\":$(psi io)"; done

# Red (por interfaz): util = bytes/s, sat = drops, err = errors
join <(echo "$N1") <(echo "$N2") | awk -v t=$INT '{printf "%s %d %d %d\n",$1,($7-$2+$8-$3)/t,$9-$4,$10-$5}' |
while read ifc bps errs drops; do emit net "$bps" "$drops" "$errs" ",\"iface\":\"$ifc\""; done

# File descriptors
read A _ M < /proc/sys/fs/file-nr
emit fd "$(awk -v a=$A -v m=$M 'BEGIN{printf "%.1f",100*a/m}')" null null ""
} >> "$LOG"