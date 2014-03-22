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
  user string,
  from_address string,
  to_address string,
  amount_mbtc int,
  record text,
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

app.get '/phat_wallets', (req, res) ->
  db.all 'SELECT address, amount_mbtc FROM wallets ORDER BY amount_mbtc DESC LIMIT 10', (err, rs) ->
    res.send 500, err if err
    res.json 200, rs

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
    JSON.stringify req.body.boilerplate
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

  db.get 'SELECT user FROM wallets WHERE address = ?', req.params.address, (err, r) ->
    return res.send 500, err if err
    return res.send 404 unless r? and r.user is user
    db.run 'UPDATE wallets SET boilerplate = ? WHERE address = ?', JSON.stringify(req.body.boilerplate), req.params.address, (err, r) ->
      return res.send 500, err if err
      res.json 200, {}

app.get '/wallets/:address', (req, res, next) ->
  db.get 'SELECT address, amount_mbtc, boilerplate FROM wallets WHERE address = ?', req.params.address, (err, r) ->
    return res.send 500, err if err
    res.json 200, r

app.post '/hack/:address', (req, res, next) ->
  user = req.session.user
  return res.send 400, 'Not logged in' unless user
  from_addr = req.params.address
  to_addr = req.query.to_address
  if !from_addr? or !to_addr?
    return res.send 404
  db.run 'BEGIN EXCLUSIVE', (err) ->
    return res.send 500, err if err
    db.get 'SELECT amount_mbtc FROM wallets WHERE address = ?', from_addr, (err, from_r) ->
      if err
        db.run 'ROLLBACK'
        return res.send 500, err
      db.get 'SELECT amount_mbtc FROM wallets WHERE address = ?', to_addr, (err, to_r) ->
        if err
          db.run 'ROLLBACK'
          return res.send 500, err
        from_amount = from_r.amount_mbtc
        to_amount = to_r.amount_mbtc
        hacked_sum = Math.ceil(from_amount * 0.1)
        from_amount -= hacked_sum
        to_amount += hacked_sum
        db.serialize ->
          db.run 'INSERT INTO transactions (user, from_address, to_address, amount_mbtc, record, timestamp) VALUES (?,?,?,?,?,datetime(\'now\'))', user, from_addr, to_addr, hacked_sum, JSON.stringify req.body.record
          db.run 'UPDATE wallets SET amount_mbtc = ? WHERE address = ?', from_amount, from_addr
          db.run 'UPDATE wallets SET amount_mbtc = ? WHERE address = ?', to_amount, to_addr
          db.run 'COMMIT', ->
            res.json 200, { amount: hacked_sum }


PORT = process.env['PORT'] ? 3000

main = ->
  app.listen PORT
  console.log "listening on http://localhost:#{PORT}"
