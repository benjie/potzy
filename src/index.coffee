context = null
node = null
sampleRate = null
sampleDuration = null
t = 0
volume = 0.1
bufferSize = 4096

$ = (id) ->
  document.getElementById(id)

window.potzy = potzy = new class
  constructor: ->
    @readyCallbacks = []
  init: =>
    $("play").addEventListener 'click', @play, false
    $("pause").addEventListener 'click', @pause, false
    @editor = CodeMirror document.body,
      mode: "javascript"
      value: """
        function dsp(t) {
          return Math.sin(2 * Math.PI * t * 440);
        }
        """
    @editor.on "change", @import
    @import()
    @editor.focus()
    try
      window.AudioContext ?= window.webkitAudioContext
      context = new AudioContext()
      sampleRate = context.sampleRate
      sampleDuration = 1 / sampleRate
      node = context.createScriptProcessor(bufferSize, 1, 1)
      node.loop = false
      node.onaudioprocess = (e) =>
        output = e.outputBuffer.getChannelData(0)
        for i in [0...output.length]
          t += sampleDuration
          output[i] = volume * @fn(t)
      @ready = true
      cb() for cb in @readyCallbacks
      delete @readyCallbacks
    catch e
      @ready = false
      alert 'Web Audio API is not supported in this browser'

  import: =>
    js = @editor.getValue()
    try
      str = """
        (function() {
          var sampleRate = #{sampleRate};
          #{js}
          return dsp;
        })()
        """
      fn = eval str
      fn(0) # Test
      fn(1) # Test
      fn(100.499) # Test
      @_fn = fn
    catch e
      console.error e

  play: =>
    node.connect(context.destination)

  pause: =>
    node.disconnect()

  _fn: -> 0

  fn: (t) ->
    try
      return @_fn(t)
    catch e
      return 0

  onReady: (fn) ->
    if @ready
      setTimeout fn, 0
    else
      @readyCallbacks.push fn

window.addEventListener 'load', window.potzy.init, false
