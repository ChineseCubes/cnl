require! {
  fs
  path
  crypto
  express
  multer
  request
  decompress: Decompress
}

running-as-script = not module.parent

service =
  stop:  (done) !->
    done? new Error 'server is not running'
  start: (done) !->
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
                res.send { sha1 }
        #r.form!append \file odp
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
