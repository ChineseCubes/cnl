require! {
  fs
  path
  crypto
  express
  multer
  request
  level
  cors
  through
  moment
  decompress: Decompress
  rsvp:         { Promise, all }
  datauri:      { promises: datauri }
  'prelude-ls': { filter, split, join, map, find }
  'recursive-readdir':     recursive
  'json-stable-stringify': stringify
  './codepoints': codepoints
  './moedict':    moedict
  './webvtt':     webvtt
}

running-as-script = not module.parent
aliases-db        = level './db/aliases'
trim              = -> it.replace /^\s+|\s+$/, ''
hyphenated        = -> it |> trim |> split ' ' |> map (.toLowerCase!) |> join '-'

not-running = (done) !-> done? new Error 'server is not running'

service =
  msg:   'you have control'
  stop:  not-running
  start: (done) !->
    aliases = []
    request do
      'https://apis-beta.chinesecubes.com/Epub/getBooklist'
      (err, res, body) ->
        for book in JSON.parse body
          dashed = hyphenated book.title
          book <<<
            alias: dashed
            timestamp: moment book.last_update .valueOf!
          aliases.push book
        aliases.sort (a, b) -> a.timestamp - b.timestamp
    ask-apis-beta = (alias, filepath, req, res) ->
      book = aliases |> find (.alias is alias)
      unless book
        return res.status 404 .send 'Not Found'
      { id, hash } = book
      request do
        "https://apis-beta.chinesecubes.com/Epub/getBookFile/#id/#hash/#filepath"
        (e, r, body) ->
          if e
            return res.status 500 .send 'Internal Error'
          if r.statusCode isnt 200
            return res.status r.statusCode .send '?'
          res.type 'json' if filepath is /.json$/
          res.send body
    (app = express!)
      .use multer dest: path.resolve 'uploads'
      .use cors!
      .get '/' (req, res) ->
        res.send service.msg
      .get '/books/' (req, res) ->
        res.send aliases
      .get '/books/:alias/' (req, res) ->
        { alias } = req.params
        ask-apis-beta alias, 'masterpage.json', req, res
      .get /\/books\/[^/]+\/.+/ (req, res) ->
        { 1: alias, 2: filepath } = /\/books\/([^/]+)\/(.+)/exec req.url
        ask-apis-beta alias, filepath, req, res
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
