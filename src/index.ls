require! {
  fs
  path
  crypto
  express
  multer
  request
  level
  cors
  decompress: Decompress
  rsvp:       { Promise, all }
  'recursive-readdir':     recursive
  'json-stable-stringify': stringify
  './codepoints': codepoints
  './moedict':    moedict
}

running-as-script = not module.parent
aliases-db        = level './db/aliases'

not-running = (done) !-> done? new Error 'server is not running'

service =
  stop:  not-running
  start: (done) !->
    aliases  = {}
    files-of = {}
    if aliases-db.isClosed!
      aliases-db.open!
    aliases-db.createReadStream!
      .on \data (data) ->
        aliases[data.key] := data.value
        book-path = path.resolve 'books', data.value, 'beta'
        recursive book-path, (err, files) ->
          throw err if err
          files-of[data.value] := files
    (app = express!)
      .use multer dest: path.resolve 'uploads'
      .use cors!
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
            fullpath = path.resolve 'books', sha1, 'beta'
            decompress = new Decompress mode: \755
              .src buffer
              .dest fullpath
              .use Decompress.zip!
              .run (err) ->
                throw err if err
                recursive fullpath, (err, files) ->
                  throw err if err
                  total = 0
                  str = ''
                  for pagepath in files
                    if /page\d+.json$/test pagepath
                      ++total
                      setImmediate do
                        (pagepath) ->
                          fs.readFile pagepath, (err, data) ->
                            str += data.toString!
                            if --total is 0
                              codepoints str, (cpts) ->
                                cpts = (for cpts => parseInt .., 16)
                                chars = (for cpts => String.fromCharCode ..)join('')
                                moedict chars, (dict) ->
                                  dictpath = path.resolve fullpath, 'dict.json'
                                  files-of[sha1]push dictpath
                                  fs.writeFile do
                                    dictpath
                                    stringify dict, space: 2
                                    -> res.send { "#alias": sha1 }
                                  # dummy mp3
                                  mp3path = path.resolve fullpath, 'audio.mp3.json'
                                  files-of[sha1]push mp3path
                                  fs.closeSync fs.openSync mp3path, \w
                                  # dummy vtt
                                  vttpath = path.resolve fullpath, 'audio.vtt.json'
                                  files-of[sha1]push vttpath
                                  fs.closeSync fs.openSync vttpath, \w
                        pagepath
                  files-of[sha1] := files
        #r.form!append \file odp
      .get '/books/' (req, res) ->
        res.send aliases
      .get '/books/:alias/' (req, res) ->
        { alias } = req.params
        sha1 = aliases[alias]
        if not sha1
          res.status 404 .send 'Not Found'
        else
          fullpath = path.resolve 'books', sha1, 'beta', 'metadata.json'
          unless fullpath in files-of[sha1]
            res.status 404 .send 'Not Found'
          else
            # XXX: is it possible to pipe it as a JSON?
            fs.readFile fullpath, (err, data) ->
              if err
                then res.status 500 .send err
                else res.send JSON.parse data
      .get /\/books\/[^/]+\/.+/ (req, res) ->
        { 1: alias, 2: filepath } = /\/books\/([^/]+)\/(.+)/exec req.url
        sha1 = aliases[alias]
        if not sha1
          res.status 404 .send 'Not Found'
        else
          fullpath = path.resolve 'books', sha1, 'beta', filepath
          unless fullpath in files-of[sha1]
            res.status 404 .send 'Not Found'
          else
            fs.readFile fullpath, (err, data) ->
              if err
                res.status 500 .send err
              else
                res
                  .type path.extname fullpath
                  .send data
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
