show_bp = (initial_data = {}, major_mode, done) ->
  # major_mode is 'edit', 'hack'

  boilerplate = document.createElement 'div'
  boilerplate.style.position = 'fixed'
  boilerplate.style.left = '0'
  boilerplate.style.top = '0'
  boilerplate.style.right = '0'
  boilerplate.style.bottom = '0'
  canvas = boilerplate.appendChild(document.createElement('canvas'))
  boilerplate.appendChild(uiCanvas = document.createElement('canvas'))
  uiCanvas.style.pointerEvents = 'none'
  document.body.appendChild boilerplate


  ctx = null

  
  UIBOXSIZE = 80
  UIBORDER = 13

  uiboxes = []

  window.onresize = ->
    uiCanvas.width = canvas.width = window.innerWidth * devicePixelRatio
    uiCanvas.height = canvas.height = window.innerHeight * devicePixelRatio
    canvas.style.width = uiCanvas.style.width = innerWidth + 'px'
    canvas.style.height = uiCanvas.style.height = innerHeight + 'px'
    ctx = canvas.getContext '2d'
    ctx.scale devicePixelRatio, devicePixelRatio

    boxes = ['move', 'nothing', 'solid', 'positive', 'negative', 'shuttle', 'thinshuttle', 'thinsolid', 'bridge']

    x = canvas.width/devicePixelRatio / 2 - (boxes.length / 2) * UIBOXSIZE
    y = canvas.height/devicePixelRatio - 100
    uiboxes.length = 0
    for mat, i in boxes
      uiboxes.push {x, y, mat}
      x += UIBOXSIZE

    console.log uiboxes

    draw?()
    #drawUI?()
    drawUIBoxes?()
  window.onresize()
   
  
  windowListeners = []
  addListener = (name, fn) ->
    window.addEventListener name, fn
    windowListeners.push {name, fn}



  resetSwitches = (simulator) ->
    for number in [0...8]
      simulator.set -1, number * 2 + 1, 'thinsolid'


  CELL_SIZE = 20
  zoom_level = 1
  size = CELL_SIZE * zoom_level



  safe = new Simulator initial_data
  active = null
  limit = {width:20, height:20}

  mode = 'editing' # or 'running'

  resetSwitches safe
  safe.set limit.width, 1, 'thinsolid'
  for y in [1..limit.height - 2]
    safe.set limit.width + 1, y, 'nothing'
    safe.set limit.width + 2, y, 'shuttle'

  scroll_x = -10 # in tile coords
  scroll_y = -2

  colors =
    #solid: 'hsl(29, 100%, 7%)'
    solid: 'hsl(184, 49%, 7%)'
    nothing: 'white'
    shuttle: 'hsl(44, 87%, 52%)'
    thinshuttle: 'hsl(44, 87%, 72%)'
    negative: 'hsl(17, 98%, 36%)'
    positive: 'hsl(170, 49%, 51%)'
    thinsolid: 'lightgrey'
    bridge: '#08f'

  placing = 'nothing'
  imminent_select = false
  selectedA = selectedB = null
  selectOffset = null
  selection = null

# given pixel x,y returns tile x,y
  screenToWorld = (px, py) ->
    return {tx:null, ty:null} unless px?
    # first, the top-left pixel of the screen is at |_ scroll * size _| px from origin
    px += Math.floor(scroll_x * size)
    py += Math.floor(scroll_y * size)
    # now we can simply divide and floor to find the tile
    tx = Math.floor(px / size)
    ty = Math.floor(py / size)
    {tx,ty}

# given tile x,y returns the pixel x,y,w,h at which the tile resides on the screen.
  worldToScreen = (tx, ty) ->
    return {px:null, py:null} unless tx?
    px: tx * size - Math.floor(scroll_x * size)
    py: ty * size - Math.floor(scroll_y * size)

  withinLimit = (x, y) ->
    0 <= x < limit.width and 0 <= y < limit.height

  copySubgrid = (rect) ->
    {tx, ty, tw, th} = rect
    subgrid = {tw,th}
    for y in [ty..ty+th]
      for x in [tx..tx+tw]
        if s = safe.grid[[x,y]]
          subgrid[[x-tx,y-ty]] = s
    subgrid

  flip = (dir) ->
    return unless selection
    new_selection = {tw:tw = selection.tw, th:th = selection.th}
    for k,v of selection
      {x:tx,y:ty} = parseXY k
      tx_ = if 'x' in dir then tw-1 - tx else tx
      ty_ = if 'y' in dir then th-1 - ty else ty
      new_selection[[tx_,ty_]] = v
    selection = new_selection

  mirror = ->
    return unless selection
    new_selection = {tw:tw = selection.th, th:th = selection.tw}
    for k,v of selection
      {x:tx,y:ty} = parseXY k
      new_selection[[ty,tx]] = v
    selection = new_selection

  timer = null
  run = ->
    return if mode is 'running'
    mode = 'running'
    active = new Simulator JSON.parse JSON.stringify safe.grid

    timer = setInterval ->
      active.step()
      draw()
    , 200

  edit = ->
    return if mode is 'editing'
    mode = 'editing'
    active = null
    clearInterval timer

  view = -> # Similar to editing.
    return if mode is 'viewing'
    mode = 'viewing'
    active = null
    clearInterval timer

  addListener 'keydown', (e) ->
    kc = e.keyCode

    switch kc
      when 32 # space
        if mode in ['editing', 'viewing']
          run()
        else
          if edit_disabled then view() else edit()

      when 16 # shift
        imminent_select = true
      when 27 # esc
        selection = selectOffset = null

      when 88 # x
        flip 'x' if selection
      when 89 # y
        flip 'y' if selection
      when 77 # m
        mirror() if selection

    pressed = ({
      # 1-8
      49: 'nothing'
      50: 'solid'
      51: 'positive'
      52: 'negative'
      53: 'shuttle'
      54: 'thinshuttle'
      55: 'thinsolid'
      56: 'bridge'

      80: 'positive' # p
      78: 'negative' # n
      83: 'shuttle' # s
      65: 'thinshuttle' # a
      69: 'nothing' # e
      71: 'thinsolid' # g
      68: 'solid' # d
      66: 'bridge' # b
    })[kc]
    if pressed?
      placing = if pressed is 'solid' then null else pressed

    if mode is 'running' and 49 <= kc <= 57
      number = kc - 49
      active.set -1, number * 2 + 1, 'negative'

    draw()

  addListener 'keyup', (e) ->
    kc = e.keyCode

    if mode is 'running'
      if 49 <= kc <= 57
        number = kc - 49
        active.set -1, number * 2 + 1, 'thinsolid'
        draw()

    if mode is 'editing'
      if kc == 16 # shift
        imminent_select = false
        draw()

  line = (x0, y0, x1, y1, f) ->
    dx = Math.abs x1-x0
    dy = Math.abs y1-y0
    ix = if x0 < x1 then 1 else -1
    iy = if y0 < y1 then 1 else -1
    e = 0
    for i in [0..dx+dy]
      f x0, y0
      e1 = e + dy
      e2 = e - dx
      if Math.abs(e1) < Math.abs(e2)
        x0 += ix
        e = e1
      else
        y0 += iy
        e = e2
    return
  paint = ->
    throw 'Invalid placing' if placing is 'move'
    {tx, ty} = mouse
    {tx:fromtx, ty:fromty} = mouse.from
    fromtx ?= tx
    fromty ?= ty

    delta = {}
    line fromtx, fromty, tx, ty, (x, y) ->
      delta[[x,y]] = placing
      safe.set x, y, placing if withinLimit x, y

    #ws.send JSON.stringify {delta}

  paste = ->
    throw new Error 'tried to paste without a selection' unless selection
    {tx:mtx, ty:mty} = screenToWorld mouse.x, mouse.y
    mtx -= selectOffset.tx
    mty -= selectOffset.ty
    delta = {}
    for y in [0...selection.th]
      for x in [0...selection.tw]
        tx = mtx+x
        ty = mty+y
        if (s = selection[[x,y]]) != safe.get tx,ty
          delta[[tx,ty]] = s or null
          safe.set tx, ty, s if withinLimit tx, ty
    #ws.send JSON.stringify {delta}

  selectMat = ->
    for {x, y, mat} in uiboxes
      if x <= mouse.x < x + UIBOXSIZE and y <= mouse.y < y + UIBOXSIZE
        placing = if mat is 'solid' then null else mat
        #mouse.mode = if mat is 'move' then null else 'paint'
        return yes

    no

  mouse = {x:null,y:null, mode:null}

  addListener 'blur', ->
    mouse.mode = null
    imminent_select = false
    if mode is 'running'
      resetSwitches active
  canvas.onmousemove = (e) ->
    return unless mode is 'editing'
    mouse.from = {tx: mouse.tx, ty: mouse.ty}
    mouse.x = e.offsetX
    mouse.y = e.offsetY
    {tx:mouse.tx, ty:mouse.ty} = screenToWorld mouse.x, mouse.y
    switch mouse.mode
      when 'paint' then paint()
      when 'select' then selectedB = screenToWorld mouse.x, mouse.y
    draw()
  canvas.onmousedown = (e) ->
    return unless mode is 'editing'
    if imminent_select
      mouse.mode = 'select'
      selection = selectOffset = null
      selectedA = screenToWorld mouse.x, mouse.y
      selectedB = selectedA
    else if selection
      paste()
    else
      if !selectMat()
        mouse.mode = 'paint'
        mouse.from = {tx:mouse.tx, ty:mouse.ty}
        paint()
    draw()
  addListener 'mousewheel', (e) ->
    e.preventDefault()

  canvas.onmouseup = ->
    if mouse.mode is 'select'
      selection = copySubgrid enclosingRect selectedA, selectedB
      selectOffset =
        tx:selectedB.tx - Math.min selectedA.tx, selectedB.tx
        ty:selectedB.ty - Math.min selectedA.ty, selectedB.ty

    mouse.mode = null
    imminent_select = false

  enclosingRect = (a, b) ->
    tx: Math.min a.tx, b.tx
    ty: Math.min a.ty, b.ty
    tw: Math.abs(b.tx-a.tx) + 1
    th: Math.abs(b.ty-a.ty) + 1

  requestAnimationFrame = window.requestAnimationFrame or
    window.webkitRequestAnimationFrame or
    window.mozRequestAnimationFrame or
    window.oRequestAnimationFrame or
    window.msRequestAnimationFrame or
    (callback) ->
      window.setTimeout(callback, 1000 / 60)

  needsDraw = false
  draw = ->
    return if needsDraw
    needsDraw = true
    requestAnimationFrame ->
      drawReal()
      #drawUI()
      drawUIBoxes()
      needsDraw = false
  drawReal = ->
    ctx.fillStyle = colors['solid']
    ctx.fillRect 0, 0, canvas.width, canvas.height
    # Draw the tiles
    simulator = if mode is 'running' then active else safe
    pressure = simulator.getPressure()
    for k,v of simulator.grid
      {x:tx,y:ty} = parseXY k
      {px, py} = worldToScreen tx, ty
      if px+size >= 0 and px < canvas.width and py+size >= 0 and py < canvas.height
        ctx.fillStyle = colors[v]
        ctx.fillRect px, py, size, size
        if v is 'nothing' and (v2 = simulator.get(tx,ty-1)) != 'nothing'
          ctx.fillStyle = colors[v2 ? 'solid']
          ctx.globalAlpha = 0.3
          ctx.fillRect px, py, size, size*0.2
          ctx.globalAlpha = 1

        if (p = pressure[k]) and p != 0
          ctx.fillStyle = if p < 0 then 'rgba(255,0,0,0.2)' else 'rgba(0,255,0,0.2)'
          ctx.fillRect px, py, size, size

    # 0,0
    zeroPos = worldToScreen 0, 0
    ctx.lineWidth = 3
    ctx.strokeStyle = 'yellow'
    ctx.strokeRect zeroPos.px, zeroPos.py, limit.width * size, limit.height * size


    mx = mouse.x
    my = mouse.y
    {tx:mtx, ty:mty} = screenToWorld mx, my
    {px:mpx, py:mpy} = worldToScreen mtx, mty

    # Selection junk
    return if mode is 'running'

    if mouse.mode is 'select'
      sa = selectedA
      sb = selectedB
    else if imminent_select
      sa = sb = {tx:mtx, ty:mty}

    ctx.lineWidth = 1
    if sa
      {tx, ty, tw, th} = enclosingRect sa, sb
      {px, py} = worldToScreen tx, ty
      ctx.fillStyle = 'rgba(0,0,255,0.5)'
      ctx.fillRect px, py, tw*size, th*size

      ctx.strokeStyle = 'rgba(0,255,255,0.5)'
      ctx.strokeRect px, py, tw*size, th*size
    else if selection
      ctx.globalAlpha = 0.8
      for y in [0...selection.th]
        for x in [0...selection.tw]
          {px, py} = worldToScreen x+mtx-selectOffset.tx, y+mty-selectOffset.ty
          if px+size >= 0 and px < canvas.width and py+size >= 0 and py < canvas.height
            v = selection[[x,y]]
            ctx.fillStyle = if v then colors[v] else colors['solid']
            ctx.fillRect px, py, size, size
      ctx.strokeStyle = 'rgba(0,255,255,0.5)'
      ctx.strokeRect mpx - selectOffset.tx*size, mpy - selectOffset.ty*size, selection.tw*size, selection.th*size
      ctx.globalAlpha = 1
    else if mpx?
      # Mouse hover
      ctx.fillStyle = colors[placing ? 'solid']
      ctx.fillRect mpx + size/4, mpy + size/4, size/2, size/2

      ctx.strokeStyle = if simulator.get(mtx, mty) then 'black' else 'white'
      ctx.strokeRect mpx + 1, mpy + 1, size - 2, size - 2


    return


  drawUIBoxes = ->
    uictx = uiCanvas.getContext '2d'
    uictx.clearRect 0, 0, uiCanvas.width, uiCanvas.height
    return unless mode is 'editing'
    uictx.save()
    uictx.scale devicePixelRatio, devicePixelRatio
    uictx.fillStyle = 'rgba(200,200,200,0.9)'

    uictx.font = 'bold 14px Arial'
    for {x, y, mat}, i in uiboxes
      color = colors[mat] ? 'yellow'

      uictx.clearShadow?()
      uictx.fillStyle = if (placing ? 'solid') is mat
        'rgba(200,200,200,0.9)'
      else
        'rgba(120,120,120,0.9)'

      uictx.fillRect x, y, UIBOXSIZE, UIBOXSIZE

      uictx.setShadow? 1, 1, 2.5, 'black'

      uictx.fillStyle = color
      uictx.fillRect x+UIBORDER, y+UIBORDER, UIBOXSIZE-2*UIBORDER, UIBOXSIZE-2*UIBORDER

      text = mat
      #width = uictx.measureText(text).width
      uictx.textAlign = 'center'
      uictx.textBaseline = 'middle'

      if mat is 'nothing'
        uictx.clearShadow?()
      else
        uictx.setShadow? 0, 0, 4, '#222'

      uictx.fillStyle = if mat is 'nothing'
        '#888'
      else
        '#eee'
      #uictx.fillText "#{i}", x + UIBOXSIZE/2, y + UIBOXSIZE/2 - 15
      uictx.fillText mat, x + UIBOXSIZE/2, y + UIBOXSIZE/2
    uictx.restore()



  addListener 'copy', (e) ->
    if selection
      console.log e.clipboardData.setData 'text', JSON.stringify selection
    e.preventDefault()

  addListener 'paste', (e) ->
    data = e.clipboardData.getData 'text'
    if data
      try
        selection = JSON.parse data
        selectOffset = {tx:0, ty:0}





  switch major_mode
    when 'edit'
      boilerplate.appendChild tag '.buttons', [
        tag 'button', 'commit', onclick: ->

      ]
    when 'hack'
      edit_disabled = yes
      view()





  draw()

  ->
    boilerplate.remove()
    for name, fn of windowListeners
      window.removeEventListener name, fn

    g = {}
    for k, v of safe.grid
      {x:tx,y:ty} = parseXY k
      g[k] = v if withinLimit tx, ty
    g

