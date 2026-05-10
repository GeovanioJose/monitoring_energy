#!/bin/bash

# Uso: ./collect.sh <duracao_segundos> <intervalo_segundos> [label]
# Exemplo: ./collect.sh 60 1 "meu_experimento"

DURATION="${1}"
INTERVAL="${2:-1}"
LABEL="${3:-coleta}"

if [ -z "$DURATION" ]; then
    echo "Uso: $0 <duracao_segundos> <intervalo_segundos> [label]"
    echo "  duracao   : tempo total de coleta em segundos"
    echo "  intervalo : intervalo entre amostras em segundos (padrão: 1)"
    echo "  label     : nome para identificar o arquivo de saída (padrão: coleta)"
    exit 1
fi

OUTDIR="out"
mkdir -p "$OUTDIR"

ENERGY_OUT="$OUTDIR/${LABEL}_energy.csv"
echo "timestamp,total,package,core,uncore,dram,cpu_temp" > "$ENERGY_OUT"

END_TIME=$(( $(date +%s) + DURATION ))
SAMPLE=1

echo -e "\e[34mIniciando coleta por ${DURATION}s (intervalo: ${INTERVAL}s) → $ENERGY_OUT\e[0m"

while [ $(date +%s) -lt $END_TIME ]; do
    package_before=$(sudo cat /sys/class/powercap/intel-rapl:0/energy_uj)
    core_before=$(sudo cat /sys/class/powercap/intel-rapl:0/intel-rapl:0:0/energy_uj)
    uncore_before=$(sudo cat /sys/class/powercap/intel-rapl:0/intel-rapl:0:1/energy_uj)
    dram_before=$(sudo cat /sys/class/powercap/intel-rapl:0/intel-rapl:0:2/energy_uj)

    sleep "$INTERVAL"

    package_after=$(sudo cat /sys/class/powercap/intel-rapl:0/energy_uj)
    core_after=$(sudo cat /sys/class/powercap/intel-rapl:0/intel-rapl:0:0/energy_uj)
    uncore_after=$(sudo cat /sys/class/powercap/intel-rapl:0/intel-rapl:0:1/energy_uj)
    dram_after=$(sudo cat /sys/class/powercap/intel-rapl:0/intel-rapl:0:2/energy_uj)

    cpu_temp=$(cat /sys/class/thermal/thermal_zone1/temp)

    package=$(echo "($package_after - $package_before)" | bc)
    core=$(echo "($core_after - $core_before)" | bc)
    uncore=$(echo "($uncore_after - $uncore_before)" | bc)
    dram=$(echo "($dram_after - $dram_before)" | bc)
    total=$(echo "($package + $dram)" | bc)

    timestamp=$(date +'%Y-%m-%dT%H:%M:%S')

    echo "$timestamp,$total,$package,$core,$uncore,$dram,$cpu_temp" >> "$ENERGY_OUT"
    echo -e "  amostra $SAMPLE | total: ${total} uJ | temp: ${cpu_temp}"
    (( SAMPLE++ ))
done

echo -e "\e[32mColeta finalizada. ${SAMPLE} amostras salvas em $ENERGY_OUT\e[0m"