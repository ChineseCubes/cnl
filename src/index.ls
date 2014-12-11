require! express

running-as-script = not module.parent

service =
  stop:  (done) !->
    done? new Error 'server is not running'
  start: (done) !->
    app = express!
    app.get '/' (req, res) ->
      res.send 'hello world'
    server = app.listen do
      process.env.PORT or 8081
      ->
        service.stop := (done) !-> server.close done
        { address, port } = server.address!
        console.log "listening at http://#address:#port" if running-as-script
        done?!

if running-as-script
  then service.start!
  else module.exports = service
