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
  rsvp:         { Promise, all }
  datauri:      { promises: datauri }
  'prelude-ls': { filter }
  'recursive-readdir':     recursive
  'json-stable-stringify': stringify
  './codepoints': codepoints
  './moedict':    moedict
  './webvtt':     webvtt
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
          url:      'https://web-beta.chinesecubes.com/sandbox/odpConvert.php'
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
                  files-of[sha1] := files
                  files = files |> filter (-> it is /page\d+.json$/)
                  ps = for pagepath in files
                    new Promise (resolve, reject) ->
                      fs.readFile pagepath, (err, data) ->
                        resolve data.toString!
                  all ps .then (pages) ->
                    str = pages.join ''
                    Promise.resolve!
                      .then ->
                        codepoints str
                      .then (cpts) ->
                        cpts = (for cpts => parseInt .., 16)
                        chars = (for cpts => String.fromCharCode ..)join('')
                        moedict chars
                      .then (dict) ->
                        dictpath = path.resolve fullpath, 'dict.json'
                        files-of[sha1]push dictpath
                        fs.writeFile do
                          dictpath
                          stringify dict, space: 2
                          -> res.send { "#alias": sha1 }
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
      .post '/books/:alias/audio.mp3' (req, res) ->
        { alias } = req.params
        sha1 = aliases[alias]
        if not sha1
          res.status 404 .send 'Not Found'
        else
          fullpath = path.resolve 'books', sha1, 'beta'
          mp3-path = req.files.mp3.path
          datauri mp3-path .then do
            ->
              json-path = path.resolve fullpath, 'audio.mp3.json'
              files-of[sha1]push json-path
              fs.writeFile do
                json-path
                "{\"mp3\":\"#{it.replace \mpeg -> \mp3}\"}"
                -> res.send 'ok'
            ->
              throw it
      .post '/books/:alias/audio.vtt' (req, res) ->
        { alias } = req.params
        sha1 = aliases[alias]
        if not sha1
          res.status 404 .send 'Not Found'
        else
          fullpath = path.resolve 'books', sha1, 'beta'
          vtt-path = req.files.webvtt.path
          webvtt do
            vtt-path
            (str) ->
              json-path = path.resolve fullpath, 'audio.vtt.json'
              files-of[sha1]push json-path
              fs.writeFile do
                json-path
                str
                -> res.send 'ok'
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
