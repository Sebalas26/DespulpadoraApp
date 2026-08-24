"""
Servidor Mock en Python para recibir Telemetría GPS en tiempo real de PulpasPro Domicilios

Requisitos:
    pip install websockets
Ejecución:
    python mock_server.py
"""

import asyncio
import json
from datetime import datetime
import websockets

PORT = 3000

async def handler(websocket):
    print("\n🟢 [WebSocket] Mensajero conectado exitosamente.")
    try:
        async for message in websocket:
            try:
                payload = json.loads(message)
                event = payload.get("event")
                
                if event == "courier_location_update":
                    data = payload.get("data", {})
                    print(
                        f"\n📍 [TELEMETRÍA EN VIVO] Mensajero: {data.get('courierName')} ({data.get('courierId')})\n"
                        f"   • Coordenadas: Lat {data.get('latitude')}, Lng {data.get('longitude')}\n"
                        f"   • Velocidad: {data.get('speed')} km/h | Rumbo: {data.get('heading')}°\n"
                        f"   • Orden Activa: {data.get('activeOrderId') or 'Ninguna (Patrulla)'}\n"
                        f"   • Batería: {data.get('batteryLevel')}% | Timestamp: {data.get('timestamp')}"
                    )
                elif event == "ping":
                    await websocket.send(json.dumps({"event": "pong", "timestamp": datetime.utcnow().isoformat()}))
            except json.JSONDecodeError:
                print(f"Mensaje crudo recibido: {message}")
    except websockets.exceptions.ConnectionClosed:
        print("\n🔴 [WebSocket] Mensajero desconectado.")

async def main():
    print(f"=======================================================")
    print(f"🚀 SERVIDOR WEBSOCKET PULPASPRO CORRIENDO EN PUERTO {PORT}")
    print(f"   • Endpoint: ws://localhost:{PORT}/ws")
    print(f"=======================================================")
    async with websockets.serve(handler, "0.0.0.0", PORT):
        await asyncio.Future()  # Correr indefinidamente

if __name__ == "__main__":
    asyncio.run(main())
