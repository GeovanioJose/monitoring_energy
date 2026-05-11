#!/usr/bin/env bash
# =============================================================================
# run.sh — Gerenciador do experimento TeaStore
# =============================================================================

set -uo pipefail


DURACAO_SEGUNDOS=12600

# ── Cores e Logs ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')] [INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[$(date '+%H:%M:%S')] [OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] [WARN]${NC}  $*"; }
err()  { echo -e "${RED}[$(date '+%H:%M:%S')] [ERRO]${NC} $*" >&2; }

if [[ $# -lt 2 ]]; then
    err "Uso: $0 <intel-rapl|codecarbon> <docker|podman>"
    exit 1
fi

ENERGY_METHOD="$1"
CONTAINER_SW="$2"

# ── Caminhos e PIDs ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$SCRIPT_DIR/out"; mkdir -p "$OUTDIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
CODECARBON_OUT="$OUTDIR/experimento_${TIMESTAMP}_codecarbon.csv"
RAPL_LABEL="experimento_${TIMESTAMP}"

TOMADA_PID=""
ENERGY_PID=""

# ── Função de Encerramento ───────────────────────────────────────────────────
cleanup() {
    echo ""
    warn "Finalizando o tempo de teste ou interrupção detectada..."
    
    if [[ -n "$TOMADA_PID" ]]; then
        kill -SIGINT "$TOMADA_PID" 2>/dev/null && ok "Processo da tomada encerrado."
    fi

    if [[ -n "$ENERGY_PID" ]]; then
        kill -SIGINT "$ENERGY_PID" 2>/dev/null && ok "Coleta de energia ($ENERGY_METHOD) encerrada."
    fi

    echo -e "Removendo containers" 

    podman stop $(podman ps -aq)
    podman rm $(podman ps -aq)

    echo -e "${GREEN}======================================================"
    echo -e " TESTE TERMINOU"
    echo -e " Saídas em: $OUTDIR"
    echo -e "======================================================${NC}"
    exit 0
}

# Trap para garantir que o cleanup rode ao final ou se você der Ctrl+C
trap cleanup EXIT INT TERM

# ── Execução ──────────────────────────────────────────────────────────────────
log "Iniciando TeaStore via $CONTAINER_SW..."
bash "$SCRIPT_DIR/start_teastore.sh" "$CONTAINER_SW"

log "Iniciando coletas em background..."

# 1. Tomada (Agora controlada por sinal)
"$SCRIPT_DIR/.venv/bin/python3" "$SCRIPT_DIR/tomada.py" &
TOMADA_PID=$!

# 2. Energia
if [[ "$ENERGY_METHOD" == "intel-rapl" ]]; then
    (cd "$OUTDIR" && bash "$SCRIPT_DIR/intel_rapl.sh" "$DURACAO_SEGUNDOS" 1 "$RAPL_LABEL") &
    ENERGY_PID=$!
else
    "$SCRIPT_DIR/.venv/bin/python3" "$SCRIPT_DIR/codecarbon.py" "$CODECARBON_OUT" &
    ENERGY_PID=$!
fi

log "Experimento rodando por $DURACAO_SEGUNDOS..."
sleep "$DURACAO_SEGUNDOS"

