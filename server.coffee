crypto = require 'crypto'
express = require 'express'
sqlite3 = require 'sqlite3'
db = new sqlite3.Database './db.sqlite'

server_secret = 'tshtsfs,65236952fa8s f892f435ls1 4f5l53f1af.78ifdad68f'

digest = (msg) ->
  crypto.createHash('sha256').update(server_secret + pass_hash).digest('hex')

# pass_hash is sha256(server_secret+sha256(user_pass))
###
db.run '''
'''
###
db.exec '''
CREATE TABLE IF NOT EXISTS users (
  user string PRIMARY KEY,
  pwd string
  );
CREATE TABLE IF NOT EXISTS wallets (
  address string,
  user string,
  amount_mbtc int,
  boilerplate text
  );
CREATE TABLE IF NOT EXISTS transactions (
  from_address string,
  to_address string,
  amount_mbtc int,
  timestamp timestamp
  );
''', (err) -> throw err if err; main()

app = express()

app.use express.static __dirname + '/static'
app.use express.cookieParser()
app.use express.cookieSession secret: 'so secret ermegherd'
app.use express.json()

###
app.get '/login', (req, res) ->
  pass_hash = req.body.pass_hash
  shasum = crypto.createHash('sha256').update(server_secret + pass_hash).digest('hex')
  res.json 200, { success: yes, user: shasum }
  res.end()
###

###
app.get '/wallets', (req, res) ->
  shasum = digest req.body.pass_hash
  db.all 'SELECT * FROM wallets WHERE owner_id = ?', shasum, (err, rows) ->
    res.json 200,
      success: yes
      wallets: rows.map (r) ->
        address: r.address
        amount_mbtc: r.amount_mbtc
        boilerplate: r.boilerplate
    res.end()

app.post '/wallets', (req, res) ->
  shasum = digest req.body.pass_hash
  address = random_address()
  db.run 'INSERT INTO wallets (address, owner_id, amount_mbtc) VALUES (?,?,?)',
    address, shasum, 0, (err, rows) ->
      res.json 200, rows.map (r) ->
        success: yes
        wallet:
          address: address
      res.end()

app.get '/wallets/:address', (req, res) ->
  db.get 'SELECT * FROM wallets WHERE address = ?', req.params.address, (err, r) ->
    throw err if err
    if r
      res.json 200,
        success: yes
        wallet:
          address: r.address
          amount_mbtc: r.amount_mbtc
          boilerplate: r.boilerplate
    else
      res.json 404, success: no
    res.end()
###

app.post '/uplink', (req, res) ->
  msg = req.body
  switch msg.a
    when 'login'
      db.get 'SELECT * FROM users WHERE user = ? AND pwd = ?', msg.user, msg.pwd, (err, r) ->
        return res.end 500, err if err

        return res.json 404, {err:'invalid'} unless r
        req.session.user = msg.user
        res.json 200, {}
      
    when 'adduser'
      db.run 'INSERT INTO users (user, pwd) VALUES (?, ?)', msg.user, msg.pwd, (err, r) ->
        console.log err, r
        return res.send 500, err if err
        req.session.user = msg.user
        res.json 200, {}

    else
      res.send 400, {err:"#{msg.a} unknown"}

app.get '/wallets', (req, res, next) ->
  user = req.session.user
  return res.send 400, 'Not logged in' unless user

  db.all 'SELECT * FROM wallets WHERE user = ?', user, (err, r) ->
    return next err if err

    res.json 200, {wallets:r}



PORT = process.env['PORT'] ? 3000

main = ->
  app.listen PORT
  console.log "listening on http://localhost:#{PORT}"
