unless window.potzy?
  context = null
  node = null
  sampleRate = null
  sampleDuration = null
  t = 0
  volume = 0.1
  bufferSize = 4096

  premade = [
    "afternoon walk"
    "early morning"
    "got some 303"
    "icecream"
    "late morning"
    "mind swift"
    "morning"
    "need more 303"
    "on the verge"
    "on the verge tech mix"
    "polytropon"
    "polytropon astral mix"
    "simple sine"
    "subwah"
    "unexpected token"
    "yay"
  ]

  $ = (id) ->
    document.getElementById(id)

  window.potzy = potzy = new class
    constructor: ->
      @readyCallbacks = []
      @state =
        L0: 0
        P0: 0
        P1: 0
        P2: 0
        P3: 0
        P4: 0
        VOL: 0
      @_state = {}
      @_state[k] = v for k, v of @state

    smooth: (newVal, oldVal) ->
      return newVal unless oldVal?
      oldRatio = 3
      return (oldRatio * oldVal + newVal)/(1 + oldRatio)

    superSmooth: (newVal, oldVal) ->
      return newVal unless oldVal?
      return oldVal unless Math.abs(oldVal - newVal) > 0.1
      return parseFloat(newVal.toFixed(1))

    setState: (@state) ->
      @_state[k] = v for k, v of @state

    setState2: (state) ->
      @_state[k] = @state[k] = @smooth(v, @state[k]) for k, v of state
      @_state.TIME = @state.TIME = @superSmooth(Math.sqrt(0.25 + @_state.P4 * 3.75), @state.TIME)
      if @_state.VOL?
        volume = Math.min(1, Math.max(0, parseFloat(@_state.VOL)))
      return

    init: =>
      fp = $("file-picker")
      list = document.createElement 'ul'
      for file in premade then do (file) =>
        li = document.createElement 'li'
        li.textContent = file
        li.onclick = => @load(file)
        li.ondblclick = => @load(file, true)
        list.appendChild li
      fp.appendChild list
      $("play").addEventListener 'click', @play, false
      $("pause").addEventListener 'click', @pause, false
      @editor = CodeMirror document.getElementById("editor"),
        mode: "javascript"
        value: """
          function dsp(t) {
            return Math.sin(2 * Math.PI * t * 440);
          }
          """
      @editor.setSize("100%", "100%")
      @editor.on "change", @import
      @import()
      if localStorage.getItem('_current')?
        @load(localStorage.getItem('_current'))
      else
        @load "basic"
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
            t += sampleDuration; #* @_state.TIME
            output[i] = volume * @fn(t)
        @ready = true
        cb() for cb in @readyCallbacks
        delete @readyCallbacks
      catch e
        @ready = false
        alert 'Web Audio API is not supported in this browser'

    load: (file, force) ->
      @currentFile = file
      localStorage.setItem('_current', file)
      if force and confirm("Delete local modifications to '#{file}'?")
        localStorage.removeItem(file)

      if !localStorage.getItem(file)? and file in premade
        xhr = new XMLHttpRequest
        xhr.onreadystatechange = =>
          if xhr.readyState is 4
            @editor.setValue(xhr.responseText)
            @import()
        xhr.open 'GET', "premade/#{file}", true
        xhr.send null
      else
        @editor.setValue(localStorage.getItem(file) ? """
          function dsp(t) {
            return Math.sin(2 * Math.PI * t * 440);
          }
          """
        )
        @import()

    import: =>
      js = @editor.getValue().replace /@([A-Za-z0-9]+)/gm, 'this.$1', 'gm'
      messagesContainer = document.getElementById 'messages'
      try
        str = """
          (function() {
            function everything(t) {
              var sampleRate = #{sampleRate};
              var P0 = this.P0;
              var P1 = this.P1;
              var P2 = this.P2;
              var P3 = this.P3;
              var P4 = this.P4;
              var L0 = this.L0;
              #{js}
              return dsp.call(this, t);
            }
            return everything;
          })()
          """
        fn = eval str
        fn.call(@_state, 0) # Test
        fn.call(@_state, 1) # Test
        fn.call(@_state, 100.499) # Test
        messagesContainer.classList.remove 'error'
        messagesContainer.innerHTML = 'OK!'
        localStorage.setItem(@currentFile, js)
        @_fn = fn
      catch e
        console.error e
        messagesContainer.classList.add 'error'
        messagesContainer.innerHTML = 'Error: ' + e.message

    play: =>
      node.connect(context.destination)

    pause: =>
      node.disconnect()

    _fn: -> 0

    fn: (t) ->
      try
        return @_fn.call(@_state, t)
      catch e
        return 0

    onReady: (fn) ->
      if @ready
        setTimeout fn, 0
      else
        @readyCallbacks.push fn

  formatValue = (input) ->
    roundedStr = (Math.round(input * 100) / 100) + ''
    return roundedStr + "0.00".substr(roundedStr.length)

  updateValueStatusBar = (state) ->
    headings = []
    values = []
    headingsContainer = document.getElementById 'vars-names'
    valuesContainer = document.getElementById 'vars-values'

    for key, value of state
      headings.push "<th>@#{key}</th>"
      #values.push "<td>#{Math.round(value * 1000) / 1000}</td>"
      values.push "<td>#{formatValue(value)}</td>"
    headingsContainer.innerHTML = headings.join ''
    valuesContainer.innerHTML = values.join ''

  window.addEventListener 'load', window.potzy.init, false

  ws = new WebSocket('ws://'+window.location.host)
  ws.onmessage = (e) ->
    try
      state = JSON.parse e.data
      potzy.setState state
      window.requestAnimationFrame -> updateValueStatusBar(potzy.state)
