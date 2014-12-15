require! {
  fs
  path
  crypto
  express
  multer
  request
  level
  decompress: Decompress
}

running-as-script = not module.parent
aliases-db        = level './db/aliases'

not-running = (done) !-> done? new Error 'server is not running'

service =
  stop:  not-running
  start: (done) !->
    aliases = {}
    if aliases-db.isClosed!
      aliases-db.open!
    aliases-db.createReadStream!
      .on \data (data) -> aliases[data.key] = data.value
    (app = express!)
      .use multer dest: path.resolve 'uploads'
      .get '/' (req, res) ->
        res.send 'hello world'
      .post '/books/' (req, res) ->
        odp-path = req.files.presentation.path
        odp = fs.readFileSync odp-path

        shasum = crypto.createHash \sha1
        shasum.update odp
        sha1 = shasum.digest \hex
        alias = req.files.presentation.originalname
        unless alias?length then alias = sha1
        aliases[alias] = sha1
        aliases-db.put alias, sha1

        decompress = new Decompress mode: \755
          .src odp
          .dest path.resolve 'books', sha1, 'odp'
          .use Decompress.zip strip: 1
          .run (err) ->
            throw err if err

        # XXX: should try superagent again later
        r = request do
          method:   \POST
          url:      'https://beta2.chinesecubes.com/sandbox/odpConvert.php'
          encoding: \binary
          # XXX: why I have to open a file twice?
          formData: file: fs.createReadStream odp-path
          (err, response, body) ->
            throw err if err
            buffer = new Buffer body, \binary
            decompress = new Decompress mode: \755
              .src buffer
              .dest path.resolve 'books', sha1, 'beta'
              .use Decompress.zip!
              .run (err) ->
                throw err if err
                res.send { "#alias": sha1 }
        #r.form!append \file odp
      .get '/books/' (req, res) ->
        res.send aliases
    server = app.listen do
      process.env.PORT or 8081
      ->
        service.stop := (done) !->
          server.close -> aliases-db.close ->
            server.stop := not-running
            done!
        { address, port } = server.address!
        console.log "listening at http://#address:#port" if running-as-script
        done?!

if running-as-script
  then service.start!
  else module.exports = service
