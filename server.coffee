crypto = require 'crypto'
express = require 'express'
sqlite3 = require 'sqlite3'
db = new sqlite3.Database './db.sqlite'

server_secret = 'tshtsfs,65236952fa8s f892f435ls1 4f5l53f1af.78ifdad68f'

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

address_chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789'
make_address = ->
  '1'+(address_chars[Math.floor(Math.random()*address_chars.length)] for [1..33]).join('')

app.post '/uplink', (req, res) ->
  msg = req.body
  switch msg.a
    when 'login'
      db.get 'SELECT * FROM users WHERE user = ? AND pwd = ?', msg.user, msg.pwd, (err, r) ->
        return res.send 500, err if err

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

app.post '/wallets', (req, res, next) ->
  user = req.session.user
  return res.send 400, 'Not logged in' unless user

  params = [
    address = make_address()
    user
    0
    JSON.stringify req.body.grid
  ]
  console.log params
  db.run '''INSERT INTO wallets (address, user, amount_mbtc, boilerplate) VALUES
                                (?, ?, ?, ?)''', params, (err, r) ->
    console.log err, r
    return res.send 500, err if err
    res.json 200, {address}

app.put '/wallets/:address', (req, res, next) ->
  user = req.session.user
  return res.send 400, 'Not logged in' unless user

  db.run 'SELECT user FROM wallets WHERE address = ?', req.params.address, (err, r) ->
    return res.send 500, err if err
    return res.send 404 unless r? and r.user is user
    db.run 'UPDATE wallets SET boilerplate = ? WHERE address = ?', req.body.grid, req.params.address, (err, r) ->
      return res.send 500, err if err
      res.send 200


PORT = process.env['PORT'] ? 3000

main = ->
  app.listen PORT
  console.log "listening on http://localhost:#{PORT}"
