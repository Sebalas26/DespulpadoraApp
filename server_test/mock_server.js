/**
 * Servidor Mock en Node.js para recibir Telemetría GPS y peticiones REST de PulpasPro Domicilios
 * 
 * Requisitos:
 *   npm install ws express cors
 * Ejecución:
 *   node mock_server.js
 */

const http = require('http');
const WebSocket = require('ws');

const PORT = 3000;

// Crear servidor HTTP básico
const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // 1. Endpoint Login: POST /api/auth/courier-login
  if (req.method === 'POST' && req.url === '/api/auth/courier-login') {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      console.log('\n📥 [REST] Login recibido:', body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          status: 'success',
          data: {
            id: 'MENSAJERO-01',
            nombre: 'Carlos Mendoza',
            placaVehiculo: 'XYZ-789 (Yamaha FZ)',
            telefono: '+57 312 456 7890',
            email: 'carlos.mendoza@pulpaspro.com',
            token: 'jwt_token_demo_courier_01',
            isOnline: true,
          },
        })
      );
    });
    return;
  }

  // 2. Endpoint Actualización de Estado: PATCH /api/orders/:id/status
  if (req.method === 'PATCH' && req.url.includes('/status')) {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      console.log(`\n📦 [REST] Cambio de Estado Orden (${req.url}):`, body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'success', message: 'Estado actualizado' }));
    });
    return;
  }

  // 3. Endpoint Novedad: POST /api/orders/:id/novelty
  if (req.method === 'POST' && req.url.includes('/novelty')) {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      console.log(`\n⚠️ [REST] Novedad Reportada (${req.url}):`, body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'success', message: 'Novedad registrada' }));
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Ruta no encontrada' }));
});

// Crear Servidor WebSocket en /ws
const wss = new WebSocket.Server({ server, path: '/ws' });

wss.on('connection', ws => {
  console.log('\n🟢 [WebSocket] Nuevo cliente/mensajero conectado.');

  ws.on('message', message => {
    try {
      const data = JSON.parse(message.toString());
      
      if (data.event === 'courier_location_update') {
        const d = data.data;
        console.log(
          `\n📍 [TELEMETRÍA EN VIVO] Mensajero: ${d.courierName} (${d.courierId})` +
          `\n   • Coordenadas: Lat ${d.latitude}, Lng ${d.longitude}` +
          `\n   • Velocidad: ${d.speed} km/h | Rumbo: ${d.heading}°` +
          `\n   • Orden Activa: ${d.activeOrderId || 'Ninguna (En patrulla)'}` +
          `\n   • Batería: ${d.batteryLevel}% | Hora: ${d.timestamp}`
        );

        // Re-emitir a clientes conectados (ej. PWA central de monitoreo)
        wss.clients.forEach(client => {
          if (client !== ws && client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(data));
          }
        });
      } else if (data.event === 'ping') {
        ws.send(JSON.stringify({ event: 'pong', timestamp: new Date().toISOString() }));
      }
    } catch (err) {
      console.log('Mensaje recibido:', message.toString());
    }
  });

  ws.on('close', () => {
    console.log('\n🔴 [WebSocket] Mensajero desconectado.');
  });
});

server.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`🚀 SERVIDOR MOCK PULPASPRO CORRIENDO EN PUERTO ${PORT}`);
  console.log(`   • REST API:    http://localhost:${PORT}/api`);
  console.log(`   • WebSocket:   ws://localhost:${PORT}/ws`);
  console.log(`=======================================================`);
});
