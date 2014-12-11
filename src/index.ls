require! express

app = express!

app.get '/' (req, res) ->
  res.send 'hello world'

server = app.listen do
  process.env.PORT or 8081
  ->
    { address, port } = server.address!
    console.log "listening at http://#address:#port"
