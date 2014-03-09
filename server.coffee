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
CREATE TABLE IF NOT EXISTS users (
  pass_hash string
  )
'''
###
db.exec '''
CREATE TABLE IF NOT EXISTS wallets (
  address string,
  owner_id string,
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
app.use express.json()

###
app.get '/login', (req, res) ->
  pass_hash = req.body.pass_hash
  shasum = crypto.createHash('sha256').update(server_secret + pass_hash).digest('hex')
  res.json 200, { success: yes, user: shasum }
  res.end()
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

PORT = process.env['PORT'] ? 3000

main = ->
  app.listen PORT
  console.log "listening on http://localhost:#{PORT}"
