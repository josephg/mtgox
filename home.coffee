tag = (name, text, attrs) ->
  parts = (name ? 'div').split /(?=[.#])/
  tagName = "div"
  classes = []
  id = undefined
  for p in parts when p.length
    switch p[0]
      when '#' then id = p.substr 1 if p.length > 1
      when '.' then classes.push p.substr 1 if p.length > 1
      else tagName = p
  element = document.createElement tagName
  element.id = id if id?
  element.classList.add c for c in classes
  for k,v of attrs ? {}
    if /^on/.test k
      element[k] = v
    else
      element.setAttribute k, v
  if typeof text is 'string' or typeof text is 'number'
    element.textContent = text
  else if text?.length?
    for e in text
      if e instanceof Node
        element.appendChild e
      else
        element.appendChild document.createTextNode e
  else if text
    element.appendChild text
  element

address_chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789'
rand_address = ->
  '1'+(address_chars[Math.floor(Math.random()*address_chars.length)] for [1..33]).join('')

intro = [
  { message: '$ ./wallet_info00.bin', time: 0 }
  { message: '-----> Accessing blockchain ...', time: 1 }
  { message: '-----> Synchronizing ...', time: 3 }
  { message: '=====> Blockchain retrieved', time: 0.2 }
  { message: 'Recent transactions:', time: 0.2 }
]

$screen = document.body.appendChild tag '.screen'
println = (l) ->
  $screen.appendChild tag '.line', l ? tag 'br'
  window.scrollTo 0, document.documentElement.scrollHeight

window.onresize = ->
  window.scrollTo 0, document.documentElement.scrollHeight

i = 0
nextIntro = ->
  println intro[i].message
  setTimeout nextIntro, intro[i].time*1000 if i+1 < intro.length
  listTransactions() if ++i is intro.length
nextIntro()

listTransactions = ->
  adds = (rand_address() for [1..10])
  txns = []
  for [1..20]
    from = adds[Math.floor(Math.random()*adds.length)]
    loop
      to = adds[Math.floor(Math.random()*adds.length)]
      break unless to is from
    amount = (Math.random()*Math.random()*Math.random()*4).toFixed(3)
    txns.push {from, to, amount}
  next = ->
    txn = txns.shift()
    println "  #{txn.amount} #{txn.to} <-- #{txn.from}"
    setTimeout next, 60 if txns.length
    done() unless txns.length
  next()
  done = -> actions()

awaiting = {}
window.onkeypress = (e) -> awaiting[e.keyCode]?()
await = (keys) ->
  awaiting[k.charCodeAt(0)] = func for k, func of keys
exec = (f) ->
  awaiting = {}
  document.getElementById('cursor').remove()
  f()

pad = (n, width, padding=' ') ->
  s = ''+n
  while s.length < width
    s = padding+s
  s
high_scores = ->
  println()
  println '==== FATTEST WALLETS ===='
  high_scores = (Math.random()*300 for [1..10]).sort (x,y) -> y-x
  for s,i in high_scores
    println "  #{pad i+1, 2}.  #{pad s.toFixed(3), 7}  #{rand_address()}"
  actions()

my_wallets = ->

actions = ->
  println()
  println ['0. ', tag 'a', 'high scores', onclick: -> exec high_scores]
  println ['1. ', tag 'a', 'my wallets', onclick: -> exec my_wallets]
  println ['2. ', tag 'a', 'logout', onclick: -> exec logout]
  println [tag('span', '> '), tag 'span#cursor']
  await
    0: -> exec high_scores
    1: -> exec my_wallets
    2: -> exec logout
