import asyncio
import csv
import time
import signal
import sys
from datetime import datetime
from kasa import Discover

# =========================
# CONFIGURAÇÕES
# =========================

IP = "192.168.0.1" # IP da tomada inteligente

INTERVALO = 300  # 5 minutos

ARQUIVO = "experimento_tapo.csv"


rodando = True

def handle_exit(sig, frame):
    global rodando
    print("\n[Tomada] Sinal de parada recebido. Encerrando...")
    rodando = False
    sys.exit(0)


signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)

# =========================
# MAIN
# =========================

async def main():

    device = await Discover.discover_single(
        IP,
        username="exemplo@email.com", # email cadastrado na tomada
        password="123456", # senha da tomada
    )

    await device.update()

    # criar CSV
    try:
        with open(ARQUIVO, "x", newline="") as f:
            writer = csv.writer(f)
            writer.writerow([
                "hora",
                "estado",
                "potencia_W",
                "kWh_intervalo",
                "kWh_acumulado"
               
                
            ])
    except FileExistsError:
        pass

    print("Iniciando experimento...\n")

    kwh_total = 0
    contador = 0

    while rodando:
        try:
            await device.update()

            if device.has_emeter:
                energy = await device.get_emeter_realtime()

                power = energy.get("power_mw", 0) / 1000
                kwh = (power * (INTERVALO / 3600)) / 1000

                kwh_total += kwh
                contador += 1

                estado = "ON" if device.is_on else "OFF"
                hora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                with open(ARQUIVO, "a", newline="") as f:
                    writer = csv.writer(f)
                    writer.writerow([
                        hora,
                        estado,
                        round(power, 3),
                        round(kwh, 6),
                        round(kwh_total, 6)
                       
                    ])

                print(f"{hora} | {power:.2f}W | {kwh:.4f} kWh")

        except Exception as e:
            print("[ERRO]", e)

        await asyncio.sleep(INTERVALO)

# =========================
# EXECUTAR
# =========================

asyncio.run(main())
