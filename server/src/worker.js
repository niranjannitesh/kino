export default {
  async fetch(request, env) {
    return await handleErrors(request, async () => {
      const url = new URL(request.url)
      const roomCode = url.pathname.slice(1)

      if (!roomCode) {
        return new Response("Room code required", { status: 400 })
      }

      // Get room DO instance
      const id = env.ROOM.idFromName(roomCode)
      const room = env.ROOM.get(id)
      return room.fetch(request)
    })
  },
}

async function handleErrors(request, func) {
  try {
    return await func()
  } catch (err) {
    if (request.headers.get("Upgrade") == "websocket") {
      let pair = new WebSocketPair()
      pair[1].accept()
      pair[1].send(JSON.stringify({ error: err.stack }))
      pair[1].close(1011, "Uncaught exception during session setup")
      return new Response(null, { status: 101, webSocket: pair[0] })
    } else {
      return new Response(err.stack, { status: 500 })
    }
  }
}

export class Room {
  constructor(state, env) {
    this.state = state
    this.env = env
    this.storage = state.storage
    this.sessions = new Map()

    // Restore any existing WebSocket sessions
    this.state.getWebSockets().forEach((webSocket) => {
      const meta = webSocket.deserializeAttachment() || {}
      this.sessions.set(webSocket, meta)
    })
  }

  async fetch(request) {
    const upgradeHeader = request.headers.get("Upgrade")
    if (!upgradeHeader || upgradeHeader !== "websocket") {
      return new Response("Expected WebSocket", { status: 426 })
    }

    const pair = new WebSocketPair()
    await this.handleSession(pair[1])

    return new Response(null, {
      status: 101,
      webSocket: pair[0],
    })
  }

  async handleSession(webSocket) {
    this.state.acceptWebSocket(webSocket)
    const clientId = crypto.randomUUID()

    // Store client metadata
    const meta = { clientId }
    webSocket.serializeAttachment(meta)
    this.sessions.set(webSocket, meta)

    this.broadcast({
      type: "clientCount",
      count: this.sessions.size,
    })

    this.log(
      `Client ${clientId} connected. Total clients: ${this.sessions.size}`
    )
  }

  async webSocketMessage(webSocket, message) {
    try {
      const data = JSON.parse(message)
      const session = this.sessions.get(webSocket)

      this.log(
        `Client ${session.clientId} sent message type: ${data.type}`,
        data
      )

      // Forward signaling messages to other clients
      this.broadcast(data, webSocket) // Don't send back to sender
    } catch (err) {
      this.log(`Error handling message: ${err.stack}`)
      webSocket.send(JSON.stringify({ error: err.stack }))
    }
  }

  async webSocketClose(webSocket) {
    const session = this.sessions.get(webSocket)
    if (session) {
      this.log(`Client ${session.clientId} disconnected`)
      this.sessions.delete(webSocket)
      this.broadcast({
        type: "clientCount",
        count: this.sessions.size,
      })
    }
  }

  async webSocketError(webSocket, error) {
    const session = this.sessions.get(webSocket)
    this.log(`WebSocket error for client ${session?.clientId}: ${error}`)
    this.sessions.delete(webSocket)
  }

  broadcast(message, skipWebSocket = null) {
    const data = JSON.stringify(message)
    this.sessions.forEach((session, webSocket) => {
      if (webSocket !== skipWebSocket) {
        try {
          webSocket.send(data)
        } catch (err) {
          this.log(`Error sending to client ${session.clientId}: ${err}`)
          this.sessions.delete(webSocket)
        }
      }
    })
  }

  log(message, data = null) {
    const logMessage = data
      ? `[Room ${this.state.id}] ${message} ${JSON.stringify(data)}`
      : `[Room ${this.state.id}] ${message}`
    console.log(logMessage)
  }
}
