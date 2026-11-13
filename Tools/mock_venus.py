#!/usr/bin/env python3
"""Имитатор Marstek Venus для проверки приложения в симуляторе без станции.

Запуск:  python3 Tools/mock_venus.py
В приложении укажите IP 127.0.0.1 и порт 30000.
"""
import json
import math
import socket
import time

HOST, PORT = "127.0.0.1", 30000
CAPACITY = 5120
start = time.time()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))
print(f"Mock Venus слушает {HOST}:{PORT}")

while True:
    data, addr = sock.recvfrom(4096)
    try:
        req = json.loads(data)
    except ValueError:
        sock.sendto(b'{"id":0,"error":{"code":-32700,"message":"Parse error"}}', addr)
        continue
    t = time.time() - start
    load = round(320 + 120 * math.sin(t / 30))
    soc = max(11, round(78 - t / 120))
    method = req.get("method")
    if method == "ES.GetStatus":
        result = {"id": 0, "bat_soc": soc, "bat_cap": CAPACITY, "pv_power": 0,
                  "ongrid_power": load, "offgrid_power": 0,
                  "total_pv_energy": 0, "total_grid_output_energy": 2548,
                  "total_grid_input_energy": 3273, "total_load_energy": 0}
    elif method == "Bat.GetStatus":
        result = {"id": 0, "soc": soc, "charg_flag": True, "dischrg_flag": True,
                  "bat_temp": 24.0, "bat_capacity": CAPACITY * soc / 100,
                  "rated_capacity": CAPACITY}
    else:
        result = {"device": "VenusE", "ver": 1}
    print(f"{method} -> soc={soc}% load={load}W")
    reply = {"id": req.get("id", 0), "src": "VenusE-mock", "result": result}
    sock.sendto(json.dumps(reply).encode(), addr)
