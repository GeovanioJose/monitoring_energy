#!/usr/bin/env bash

# Configurações de erro (Sintaxe Moderna/Segura)
# -e: para o script se um comando falhar
# -u: trata variáveis não definidas como erro
# -o pipefail: captura falhas em comandos encadeados por pipes
set -euo pipefail

# Variáveis fornecidas
readonly JMETER_PATH="/home/jojema/Transferências/apache-jmeter-5.6.3/bin/jmeter"
readonly NUM_USERS=100
readonly RAMP_UP=60
readonly HOST_IP="192.168.0.105"
readonly PORT=8080
readonly FILE_PREFIX="logs_cycle"
readonly JMX_FILE= "teastore_browse_nogui.jmx"
# Loop de 1 a 5 usando expansão de chaves {1..5}
for i in {1..5}; do
    echo "Iniciando Ciclo $i de 5"

    # Criamos o nome do arquivo único para este ciclo
    CURRENT_LOG="${FILE_PREFIX}_${i}.csv"
    
    # 1. Espera 10 minutos sem workload
    echo "Aguardando 10 minutos de repouso..."
    sleep 10m

    # 2. Inicia workload em background
    echo "Iniciando carga de trabalho (Workload)..."
    
    # Executando JMeter no modo No-GUI (-n)
    "$JMETER_PATH" -n -t "$JMX_FILE" \
        -l "$CURRENT_LOG" \
        -Jusers="$NUM_USERS" \
        -Jrampup="$RAMP_UP" \
        -Jhost="$HOST_IP" \
        -Jport="$PORT" \
        -Jfilename="$CURRENT_LOG" &
    
    # Captura o PID (Process ID) do último comando enviado para background
    WORKLOAD_PID=$!
    echo "Workload rodando sob o PID: $WORKLOAD_PID"

    # 3. Espera 30 minutos enquanto o workload roda
    echo "Mantendo carga por 30 minutos..."
    sleep 30m

    # 4. Mata o workload
    echo "Tempo esgotado. Encerrando processo $WORKLOAD_PID..."
    
    # Tenta encerrar graciosamente, se não, força
    if kill -0 "$WORKLOAD_PID" 2>/dev/null; then
        kill "$WORKLOAD_PID"
        echo "Ciclo $i finalizado com sucesso."
    else
        echo "O processo já havia terminado antes do tempo."
    fi

done

sleep 10m

echo "Fluxo completo finalizado."