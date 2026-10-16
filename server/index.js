const http = require("node:http");
const { randomUUID } = require("node:crypto");
const { WebSocketServer, WebSocket } = require("ws");

const PORT = Number(process.env.PORT) || 3000;
const MAX_PLAYERS = 8;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const rooms = new Map();
const clients = new Map();

const server = http.createServer((req, res) => {
  if (req.url === "/" || req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({
      ok: true,
      service: "Nerf Blaster Arena 3D multiplayer server",
      rooms: rooms.size,
      message: "Server is running. Connect with a WebSocket client to create or join a room."
    }));
    return;
  }
  res.writeHead(404, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify({ error: "Not found" }));
});

const wss = new WebSocketServer({
  server,
  maxPayload: 16 * 1024,
  perMessageDeflate: false
});

function send(ws, type, data = {}) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type, ...data }));
  }
}

function broadcast(room, type, data = {}, except = null) {
  for (const player of room.players.values()) {
    if (player.ws !== except) send(player.ws, type, data);
  }
}

function makeCode() {
  for (let attempt = 0; attempt < 100; attempt++) {
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    }
    if (!rooms.has(code)) return code;
  }
  throw new Error("Could not allocate a room code");
}

function publicPlayers(room) {
  return [...room.players.values()].map(({ id, name, x, y, z, rotation, downed }) => ({
    id, name, x, y, z, rotation, downed
  }));
}

function leaveRoom(ws) {
  const client = clients.get(ws);
  if (!client || !client.roomCode) return;
  const room = rooms.get(client.roomCode);
  if (room) {
    room.players.delete(client.id);
    broadcast(room, "player-left", { playerId: client.id });
    if (room.players.size === 0) {
      rooms.delete(room.code);
    } else {
      broadcast(room, "room-state", {
        roomCode: room.code,
        players: publicPlayers(room),
        wave: room.wave
      });
    }
  }
  client.roomCode = null;
}

function enterRoom(ws, code, name) {
  const client = clients.get(ws);
  if (!client) return;
  const room = rooms.get(code);
  if (!room) return send(ws, "error", { message: "Room not found. Check the code and try again." });
  if (room.players.size >= MAX_PLAYERS) return send(ws, "error", { message: "That room is full (maximum 8 players)." });
  if (room.players.has(client.id)) return;

  leaveRoom(ws);
  client.roomCode = code;
  const player = {
    id: client.id,
    name: String(name || "Player").replace(/[<>\u0000-\u001f]/g, "").trim().slice(0, 18) || "Player",
    ws,
    x: 0,
    y: 0,
    z: 0,
    rotation: 0,
    downed: false
  };
  room.players.set(player.id, player);
  send(ws, "room-joined", {
    roomCode: room.code,
    playerId: player.id,
    host: room.hostId === player.id,
    maxPlayers: MAX_PLAYERS,
    players: publicPlayers(room),
    wave: room.wave
  });
  broadcast(room, "player-joined", {
    player: { id: player.id, name: player.name, x: player.x, y: player.y, z: player.z, rotation: player.rotation, downed: player.downed }
  }, ws);
  broadcast(room, "room-state", {
    roomCode: room.code,
    players: publicPlayers(room),
    wave: room.wave
  });
}

wss.on("connection", (ws) => {
  const client = { id: randomUUID(), roomCode: null };
  clients.set(ws, client);
  send(ws, "connected", { playerId: client.id, maxPlayers: MAX_PLAYERS });

  ws.on("message", (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return send(ws, "error", { message: "Invalid message format." });
    }
    if (!msg || typeof msg.type !== "string") return send(ws, "error", { message: "Message type is required." });

    if (msg.type === "create-room") {
      leaveRoom(ws);
      const code = makeCode();
      const room = { code, hostId: client.id, players: new Map(), wave: 1 };
      rooms.set(code, room);
      enterRoom(ws, code, msg.name);
      return;
    }

    if (msg.type === "join-room") {
      const code = String(msg.code || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
      if (code.length !== 6) return send(ws, "error", { message: "Enter a 6-character room code." });
      enterRoom(ws, code, msg.name);
      return;
    }

    if (msg.type === "leave-room") {
      leaveRoom(ws);
      send(ws, "left-room");
      return;
    }

    const current = clients.get(ws);
    const room = current?.roomCode ? rooms.get(current.roomCode) : null;
    if (!room) return send(ws, "error", { message: "Create or join a room first." });

    if (msg.type === "position") {
      const player = room.players.get(client.id);
      if (!player) return;
      const safeNumber = (value, fallback) => Number.isFinite(value) ? Math.max(-10000, Math.min(10000, value)) : fallback;
      player.x = safeNumber(msg.x, player.x);
      player.y = safeNumber(msg.y, player.y);
      player.z = safeNumber(msg.z, player.z);
      player.rotation = safeNumber(msg.rotation, player.rotation);
      broadcast(room, "player-moved", {
        playerId: player.id,
        x: player.x, y: player.y, z: player.z, rotation: player.rotation
      }, ws);
      return;
    }

    if (msg.type === "wave") {
      // Only the room host may publish the room's wave number.
      // This synchronizes the room's shared wave indicator; enemy simulation
      // remains client-side until enemy state/combat replication is implemented.
      const requestedWave = Number(msg.wave);
      if (client.id !== room.hostId) {
        send(ws, "wave-sync", { wave: room.wave, hostOnly: true });
        return;
      }
      if (!Number.isInteger(requestedWave) || requestedWave < 1 || requestedWave > 100000) {
        return send(ws, "error", { message: "Invalid wave number." });
      }
      room.wave = requestedWave;
      broadcast(room, "wave-sync", { wave: room.wave, hostId: room.hostId });
      return;
    }

    if (msg.type === "ping") {
      send(ws, "pong", { time: Date.now() });
      return;
    }

    send(ws, "error", { message: "Unknown message type." });
  });

  ws.on("close", () => {
    leaveRoom(ws);
    clients.delete(ws);
  });

  ws.on("error", () => {
    leaveRoom(ws);
    clients.delete(ws);
  });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Nerf Blaster Arena multiplayer server listening on port ${PORT}`);
});
