################################################################ Libraries #
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

xhr = (method, url, payload, callback) ->
  r = new XMLHttpRequest()
  r.open method, url, true
  r.setRequestHeader 'Content-Type', 'application/json' if payload

  r.onload = ->
    if r.status != 200
      callback r.status
    else
      callback null, (if r.responseText then JSON.parse r.responseText)

  try
    r.send (if payload then JSON.stringify payload)
  catch e
    callback e.message

################################################################### Screen #
$screen = document.body.appendChild tag '.screen'
println = (l) ->
  $screen.appendChild tag '.line', l ? tag 'br'
  window.scrollTo 0, document.documentElement.scrollHeight

window.onresize = ->
  window.scrollTo 0, document.documentElement.scrollHeight

awaiting = {}
window.onkeypress = (e) ->
  if (f = awaiting[e.keyCode])
    awaiting = {}
    f()

await = (keys) ->
  awaiting[k.charCodeAt(0)] = func for k, func of keys

menu = (items) ->
  println()
  i = 0
  my_events = {}
  for k,v of items
    f = do (v) -> ->
      cancelMenu()
      v()
    println [i+'. ', tag 'a.menu', k, onclick: f]
    my_events[i] = f
    i++
  println [tag('span', '> '), tag 'span#cursor']
  await my_events

cancelMenu = ->
  awaiting = {}
  document.getElementById('cursor').remove()

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

################################################################ Utilities #
request = (data, callback) ->
  println "-------->"
  xhr 'POST', '/uplink', data, (err, response) ->
    if err
      println "ERR #{(err.message ? err)}"
      callback err
    else
      println "<---GOT RESPONSE"
      callback null, response


pad = (n, width, padding=' ') ->
  s = ''+n
  while s.length < width
    s = padding+s
  s

fullscreen = (content) ->
  document.body.appendChild fs = tag '.fullscreen', content

##################################################################### Game #

current_user = null

###

intro = [
  { message: '$ ./wallet_info00.bin', time: 0 }
  { message: '-----> Accessing blockchain ...', time: 1 }
  { message: '-----> Synchronizing ...', time: 3 }
  { message: '=====> Blockchain retrieved', time: 0.2 }
  { message: 'Recent transactions:', time: 0.2 }
]
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


init = ->
  println '\\_\\  /_/ woo things banner'
  println()
  decide
    'login': login_flow
    'adduser': adduser_flow

#------------------------------------------------------ Login/registration -
login_flow = ->
  prompt 'login: ', (user) ->
    prompt 'password: ', (pwd) ->
      request {a:'login', user, pwd}, (err, response) ->
        console.log response
        if !err
          current_user = user
          root_actions()

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
                root_actions()

#--------------------------------------------------------------- Main menu -
root_actions = ->
  menu
    'scan': scan
    'my wallets': my_wallets
    'logout': logout

logout = ->
  root_actions()

#-------------------------------------------------------------------- Scan -
scan = ->
  menu
    'return': root_actions
    'prime targets': print_high_scores
    #'random wallet': random_wallet

print_high_scores = ->
  println()
  xhr 'GET', '/phat_wallets', null, (err, data) ->
    println '==== PHATTEST WALLETS ===='
    for {address, amount_mbtc},i in data
      println [
        "  #{pad i+1, 2}.  #{pad (amount_mbtc/1000).toFixed(3), 7}  "
        tag 'a', address, onclick: do (address) -> -> cancelMenu(); hack address, root_actions
      ]
    scan()

#-------------------------------------------------------------- My wallets -
my_wallets = ->
  xhr 'GET', '/wallets', null, (err, data) ->
    if not data?.wallets?
      println "--- NO WALLETS ---"
    else
      println "    BTC  ADDRESS"
      for w in data.wallets
        w.boilerplate = JSON.parse w.boilerplate
        println [
          " #{pad (w.amount_mbtc/1000).toFixed(3), 6}  "
          tag 'a', w.address, onclick: do (w) -> ->
            cancelMenu()
            edit_wallet w
        ]
    menu
      'create wallet': -> edit_wallet {address: null, boilerplate: {}}
      #'transfer BTC': transfer
      #'delete wallet': delete_wallet

      'return': root_actions

edit_wallet = (wallet) ->
  fs = fullscreen [
    $actions = tag '.actions', [
      tag 'a', '< back', onclick: ->
        b.unregister()
        fs.remove()
        my_wallets()
      ' '
      tag 'button', 'VERIFY', onclick: ->
        b.unregister()
        fs.remove()
        verify_wallet {address: wallet.address, boilerplate: b.grid()}
    ]
    tag '.wallet', [
      (b = new Boilerplate wallet.boilerplate).el
    ]
  ]
  do window.onresize = ->
    b.resizeTo innerWidth, innerHeight - $actions.getBoundingClientRect().height
  b.edit()

verify_wallet = (wallet) ->
  fs = fullscreen [
    $actions = tag '.actions', [
      tag 'a', '< back', onclick: ->
        b.unregister()
        fs.remove()
        edit_wallet wallet
      ' '
      $save = tag 'button', 'SAVE', disabled: 'disabled', onclick: ->
        b.unregister()
        fs.remove()
        save_wallet wallet
    ]
    tag '.wallet', [
      (b = new Boilerplate wallet.boilerplate).el
    ]
  ]
  do window.onresize = ->
    b.resizeTo innerWidth, innerHeight - $actions.getBoundingClientRect().height
  b.run ->
    if b.is_solved()
      b.stop()
      $save.removeAttribute 'disabled'

save_wallet = (wallet) ->
  done = (err, data) ->
    if err
      return println 'ERR ' + JSON.stringify err
    println JSON.stringify data
    my_wallets()

  if wallet.address?
    xhr 'PUT', '/wallets/'+wallet.address, {boilerplate: wallet.boilerplate}, done
  else
    xhr 'POST', '/wallets', {boilerplate: wallet.boilerplate}, done



#----------------------------------------------------------------- Hacking -
hack = (address, cb) ->
  xhr 'GET', '/wallets/'+address, null, (err, wallet) ->
    if err
      return println 'ERR ' + JSON.stringify err
    fs = fullscreen [
      $actions = tag '.actions', [
        tag 'a', '< back', onclick: ->
          b.unregister()
          fs.remove()
          cb()
        ' '
        tag 'span', "#{(wallet.amount_mbtc/1000).toFixed(3)} BTC"
      ]
      tag '.wallet', [
        (b = new Boilerplate JSON.parse wallet.boilerplate).el
      ]
    ]
    do window.onresize = ->
      b.resizeTo innerWidth, innerHeight - $actions.getBoundingClientRect().height
    b.run ->
      if b.is_solved()
        b.stop()
        b.unregister()
        fs.remove()
        choose_hack_dest wallet, b.record

choose_hack_dest = (wallet, record) ->
  println "04_ttx:  wallet #{wallet.address} compromised. #{wallet.amount_mbtc/10} BTC recovered."
  xhr 'GET', '/wallets', null, (err, data) ->
    if not data?.wallets?
      println "--- NO WALLETS ---"
    else
      println "choose destination wallet:"
      println "    BTC  ADDRESS"
      opts = {}
      for w in data.wallets
        opts[w.address] = do (w) -> ->
          println "manipulating blockchain..."
          xhr 'POST', '/hack/'+wallet.address+'?to_address='+w.address, { record }, (err, data) ->
            if err
              println "ERR " + err
              return choose_hack_dest wallet, record
            println "transaction created. #{data.amount} BTC transferred to #{w.address}"
            scan()
      menu opts

init()
