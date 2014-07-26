http = require 'http'
express = require 'express'
WebSocket = require 'ws'
WebSocketServer = WebSocket.Server
Espruino = require 'node-espruino'

start = ->
  if err?
    console.dir err
    process.exit 1

  device = new class
    constructor: ->
      @sockets = []
      @state = {}
      @getState()
    getState: =>
      done = =>
        setTimeout @getState, 10
        clearTimeout watchdog
        done = ->
      watchdog = setTimeout done, 200
      espruino.command 'getState()', (result) =>
        done()
        try
          @state = JSON.parse(result)
          @broadcastState()
    addWebsocket: (ws) =>
      console.log "Got websocket connection"
      @sockets.push ws
      ws.on 'close', => @removeWebsocket(ws)
      @sendState(ws)
    removeWebsocket: (ws) =>
      console.log "Lost websocket connection"
      # Should definitely exist, unless there's a bug somewhere.
      @sockets.splice(@sockets.indexOf(ws), 1)
    sendState: (ws) ->
      ws.send JSON.stringify(@state), -> # ignore errors
    broadcastState: ->
      @sendState(ws) for ws in @sockets

  app = express()
  server = http.createServer app
  app.use express.static __dirname
  wss = new WebSocketServer server:server
  wss.on 'connection', device.addWebsocket

  server.listen 1337

espruino = Espruino.espruino comPort: process.env.TTY
espruino.open (err) ->
  throw err if err?
  getState = ->
    P0: analogRead(A1)
    P1: analogRead(A0)
    P2: analogRead(C3)
    P3: analogRead(C2)
    P4: analogRead(C1)
    P5: analogRead(C0)
    L0: analogRead(A3)

  sig = getState.toString()
  sig = sig.replace /^function ?/, "function getState"
  espruino.command sig, start
