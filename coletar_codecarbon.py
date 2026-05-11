"""
coletar_codecarbon.py — Coleta emissões e energia via Code Carbon
Modo: medição contínua com exportação para CSV por amostra
"""

import sys
import os
import csv
import time
import signal
from datetime import datetime

# Ajuste no import: agora utilizando a classe Offline específica da biblioteca
try:
    from codecarbon import OfflineEmissionsTracker
except ImportError:
    print("ERRO: Code Carbon não instalado. Execute: pip3 install codecarbon", file=sys.stderr)
    sys.exit(1)

# Configurações via ambiente ou default
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

    # Configuração do Tracker Offline conforme documentação
    tracker = OfflineEmissionsTracker(
        project_name="experimento_envelhecimento",
        measure_power_secs=INTERVALO,
        country_iso_code=PAIS,
        region=REGIAO,
        save_to_file=False,           # Manter False para controlarmos a escrita via CSV manual
        log_level="error",
        tracking_mode="machine",      # "machine" captura o consumo total do sistema/nó
        rapl_include_dram=True        # Importante para pesquisa: inclui DRAM via RAPL no Linux
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

    print(f"[CodeCarbon] Iniciando coleta offline ({PAIS}/{REGIAO}) → {arquivo_saida}", file=sys.stderr)
    tracker.start()

    t_ultimo = time.time()

    try:
        with open(arquivo_saida, "w", newline="") as f:
            escritor = csv.DictWriter(f, fieldnames=cabecalho)
            escritor.writeheader()

            while rodando:
                time.sleep(INTERVALO)
                agora = time.time()
                duracao = agora - t_ultimo
                t_ultimo = agora

                try:
                    # Acessando métricas em tempo real
                    cpu_power = tracker._total_cpu_power.W if hasattr(tracker, "_total_cpu_power") else 0
                    ram_power = tracker._total_ram_power.W if hasattr(tracker, "_total_ram_power") else 0

                    # Métricas acumuladas
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
                        "cpu_power_W":        round(cpu_power, 3),
                        "ram_power_W":        round(ram_power, 3),
                    }

                    escritor.writerow(linha)
                    f.flush()

                except Exception as e:
                    print(f"[CodeCarbon] Aviso na coleta: {e}", file=sys.stderr)
                    
    finally:
        # Garante que o tracker pare mesmo se houver erro no loop
        emissoes_finais = tracker.stop()
        print(f"\n[CodeCarbon] Encerrado. Emissões totais estimadas: {emissoes_finais if emissoes_finais else 0:.6f} kgCO2", file=sys.stderr)

if __name__ == "__main__":
    main()
