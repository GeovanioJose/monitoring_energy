"""
coletar_codecarbon.py — Coleta emissões e energia via Code Carbon
Modo: medição contínua com exportação para CSV por amostra

Uso: python3 coletar_codecarbon.py <arquivo_saida.csv>
"""

import sys
import os
import csv
import time
import signal
from datetime import datetime

try:
    from codecarbon import EmissionsTracker
except ImportError:
    print("ERRO: Code Carbon não instalado. Execute: pip3 install codecarbon", file=sys.stderr)
    sys.exit(1)

INTERVALO = float(os.environ.get("CODECARBON_INTERVALO", 10))
PAIS = os.environ.get("CODECARBON_PAIS", "BRA")
REGIAO = os.environ.get("CODECARBON_REGIAO", "pernambuco")

rodando = True

def sair(sig, frame):
    global rodando
    rodando = False

signal.signal(signal.SIGTERM, sair)
signal.signal(signal.SIGINT, sair)


def main():
    if len(sys.argv) < 2:
        print("Uso: python3 coletar_codecarbon.py <saida.csv>", file=sys.stderr)
        sys.exit(1)

    arquivo_saida = sys.argv[1]

    # CodeCarbon em modo offline (não depende de conexão)
    tracker = EmissionsTracker(
        project_name="experimento",
        measure_power_secs=INTERVALO,
        country_iso_code=PAIS,
        save_to_file=False,      # Controlamos a saída manualmente
        log_level="error",
    )

    cabecalho = [
        "timestamp",
        "duracao_s",
        "energia_CPU_kWh",
        "energia_RAM_kWh",
        "energia_total_kWh",
        "emissoes_kgCO2",
        "taxa_emissao_kgCO2_kWh",
        "cpu_power_W",
        "ram_power_W",
    ]

    print(f"[CodeCarbon] Iniciando coleta → {arquivo_saida}", file=sys.stderr)
    tracker.start()

    amostras = []
    t_ultimo = time.time()

    with open(arquivo_saida, "w", newline="") as f:
        escritor = csv.DictWriter(f, fieldnames=cabecalho)
        escritor.writeheader()

        while rodando:
            time.sleep(INTERVALO)
            agora = time.time()
            duracao = agora - t_ultimo
            t_ultimo = agora

            # Acessa métricas internas do tracker sem parar
            try:
                cpu_power = tracker._total_cpu_power.W if hasattr(tracker, "_total_cpu_power") else None
                ram_power = tracker._total_ram_power.W if hasattr(tracker, "_total_ram_power") else None

                # Emissões acumuladas desde o início
                emissoes_acc = tracker._total_emissions if hasattr(tracker, "_total_emissions") else 0
                energia_cpu  = tracker._total_cpu_energy.kWh if hasattr(tracker, "_total_cpu_energy") else 0
                energia_ram  = tracker._total_ram_energy.kWh if hasattr(tracker, "_total_ram_energy") else 0
                energia_total = energia_cpu + energia_ram

                linha = {
                    "timestamp":          datetime.now().isoformat(timespec="milliseconds"),
                    "duracao_s":          round(duracao, 2),
                    "energia_CPU_kWh":    round(energia_cpu, 8),
                    "energia_RAM_kWh":    round(energia_ram, 8),
                    "energia_total_kWh":  round(energia_total, 8),
                    "emissoes_kgCO2":     round(emissoes_acc, 8),
                    "taxa_emissao_kgCO2_kWh": round(emissoes_acc / energia_total, 4) if energia_total > 0 else 0,
                    "cpu_power_W":        round(cpu_power, 3) if cpu_power else "",
                    "ram_power_W":        round(ram_power, 3) if ram_power else "",
                }

                escritor.writerow(linha)
                f.flush()

            except Exception as e:
                print(f"[CodeCarbon] Aviso na coleta: {e}", file=sys.stderr)

    # Finaliza e salva emissão total
    emissoes_finais = tracker.stop()
    print(f"[CodeCarbon] Encerrado. Emissões totais: {emissoes_finais:.6f} kgCO2", file=sys.stderr)
    print(f"[CodeCarbon] Arquivo: {arquivo_saida}", file=sys.stderr)


if __name__ == "__main__":
    main()
