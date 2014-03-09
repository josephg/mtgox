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

current_user = null







###
nextIntro = do ->
  i = 0
  ->
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
###

awaiting = {}
window.onkeypress = (e) ->
  if (f = awaiting[e.keyCode])
    awaiting = {}
    document.getElementById('cursor').remove()
    f()

await = (keys) ->
  awaiting[k.charCodeAt(0)] = func for k, func of keys

pad = (n, width, padding=' ') ->
  s = ''+n
  while s.length < width
    s = padding+s
  s
print_high_scores = ->
  println()
  println '==== FATTEST WALLETS ===='
  high_scores = (Math.random()*300 for [1..10]).sort (x,y) -> y-x
  for s,i in high_scores
    println "  #{pad i+1, 2}.  #{pad s.toFixed(3), 7}  #{rand_address()}"
  actions()

my_wallets = ->
  actions()

logout = ->
  actions()

actions = ->
  println()
  println ['0. ', tag 'a', 'high scores', onclick: print_high_scores]
  println ['1. ', tag 'a', 'my wallets', onclick: my_wallets]
  println ['2. ', tag 'a', 'logout', onclick: logout]
  println [tag('span', '> '), tag 'span#cursor']
  await
    0: print_high_scores
    1: my_wallets
    2: logout


decide = (options) ->
  println (for k, v of options
    tag 'span.option', ['[ ', tag('a', k, onclick:v), ' ]  ']
  )

prompt = (str, callback) ->
  println [tag('span', str), $entry = tag('span.entry'), $cursor = tag 'span#cursor']
  window.addEventListener 'keypress', keypress = (e) ->
    $entry.textContent += String.fromCharCode(e.charCode)
  window.addEventListener 'keydown', keydown = (e) ->
    if e.keyCode is 8
      $entry.textContent = $entry.textContent.substr 0, $entry.textContent.length-1
      e.preventDefault()
    else if e.keyCode is 85 and e.ctrlKey
      # ctrl+u
      $entry.textContent = ''
      e.preventDefault()
    else if e.keyCode is 13
      # Enter
      window.removeEventListener 'keypress', keypress
      window.removeEventListener 'keydown', keydown
      $cursor.remove()
      callback $entry.textContent



xhr = (payload, callback) ->
  request = new XMLHttpRequest()
  request.open 'POST', '/uplink', true
  request.setRequestHeader 'Content-Type', 'application/json'

  request.onload = ->
    if request.status != 200
      callback request.status
    else
      callback null, JSON.parse request.responseText

  try
    request.send JSON.stringify payload
  catch e
    callback e.message

request = (data, callback) ->
  println "-------->"
  xhr data, (err, response) ->
    if err
      println "ERR #{(err.message ? err)}"
      callback err
    else
      println "<---GOT RESPONSE"
      callback null, response


login_flow = ->
  prompt 'login: ', (user) ->
    prompt 'password: ', (pwd) ->
      request {a:'login', user, pwd}, (err, response) ->
        console.log response
        if !err
          current_user = user
          actions()

adduser_flow = ->
  prompt 'handle: ', (user) ->
    return println "adduser: The user `root' already exists." if user is 'root'

    println "Adding user `#{user}' ..."
    uid = (Math.random() * 10000) |0
    gid = (Math.random() * 10000) |0
    println "Adding new group `#{user}' (#{gid}) ..."
    println "Adding new user `#{user}' (#{uid}) with group `#{user}' ..."
    println "Creating home directory `/home/#{user}' ..."
    println "Copying files from `/etc/skel' ..."
    do enterPwd = ->
      prompt "Enter new UNIX password: ", (pwd) ->
        prompt "Retype new UNIX password: ", (pwd2) ->
          if pwd != pwd2
            println "Sorry, passwords do not match"
            println "passwd: Authentication token manipulation error"
            println "passwd: password unchanged"
            println "Try again? [y/N] y"
            enterPwd()
          else
            request {a:'adduser', user, pwd}, (err) ->
              if !err
                println "passwd: password updated successfully"
                current_user = user
                actions()




init = ->
  println '\\_\\  /_/ woo things banner'
  println()
  decide
    'login': login_flow
    'adduser': adduser_flow


init()
