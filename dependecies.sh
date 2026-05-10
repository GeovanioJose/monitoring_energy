#!/usr/bin/env bash
# =============================================================================
# dependecies.sh — Instalação de dependências e configuração do VENV
# =============================================================================

set -e

echo "[INFO] Atualizando listas de pacotes..."
sudo apt-get update

echo "[INFO] Instalando Podman, Python3-VENV e utilitários..."
# bc é necessário para o cálculo no intel_rapl.sh
sudo apt-get install -y podman python3-venv python3-pip bc

# ── Configuração do Ambiente Virtual (VENV) ──────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "[INFO] Criando ambiente virtual em $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "[INFO] Ambiente virtual já existe."
fi

echo "[INFO] Instalando dependências Python dentro do venv..."
# Atualiza o pip e instala as libs necessárias para codecarbon.py e tomada.py
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install codecarbon python-kasa

echo "========================================"
echo " CONFIGURAÇÃO CONCLUÍDA"
echo "========================================"