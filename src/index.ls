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
  'prelude-ls': { filter, split, join, map, find }
  'recursive-readdir':     recursive
  'json-stable-stringify': stringify
  './codepoints': codepoints
  './moedict':    moedict
}

api-host          = 'https://apis-beta.chinesecubes.com'
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
    dicts = {}
    request do
      "#api-host/Epub/getBooklist"
      (err, res, body) ->
        for book in JSON.parse body
          dashed = hyphenated book.title
          book <<<
            alias: dashed
            timestamp: moment book.last_update .valueOf!
          aliases.push book
        aliases.sort (a, b) -> +a.id - +b.id
        ps = for let { id, hash, alias } in aliases
          new Promise (resolve, reject) ->
            request do
              "#api-host/Epub/getBookFile/#id/#hash/masterpage.json"
              (e, r, body) ->
                throw e if e
                return unless r.statusCode is 200
                page-num = +JSON.parse body .attrs['TOTAL-PAGES']
                ps = for i from 1 to page-num
                  new Promise (resolve, reject) ->
                    request do
                      "#api-host/Epub/getBookFile/#id/#hash/page#i.json"
                      (e, r, body) ->
                        throw e if e
                        return reject r unless r.statusCode is 200
                        resolve body
                all ps
                  .then ->
                    codepoints it.join ''
                  .then (cpts) ->
                    cpts  = (for cpts => parseInt .., 16)
                    chars = (for cpts => String.fromCharCode ..)join('')
                    console.log "generating dict.json: #alias"
                    resolve dicts[alias] := moedict chars
        all ps .then -> console.log "all dict.json are ready"
    ask-apis-beta = (alias, filepath, req, res) ->
      console.log filepath
      book = aliases |> find (.alias is alias)
      unless book
        return res.status 404 .send 'Not Found'
      { id, hash } = book
      request do
        "#api-host/Epub/getBookFile/#id/#hash/#filepath"
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
      .get '/books/:alias/dict.json' (req, res) ->
        { alias } = req.params
        book = aliases |> find (.alias is alias)
        unless book
          return res.status 404 .send 'Not Found'
        dicts[alias]then -> res.json it
      .get '/books/:alias/audio.mp3.json' (req, res) ->
        { alias } = req.params
        book = aliases |> find (.alias is alias)
        unless book
          return res.status 404 .send 'Not Found'
        { id, hash } = book
        request do
          "#api-host/Epub/getBookFile/#id/#hash/audio.mp3"
          (e, r, body) ->
            base64 = new Buffer(body)toString(\base64)
            res
              .type \json
              .send "{\"mp3\":\"data:audio/mp3;base64,#base64\"}"
      .get '/books/:alias/audio.vtt.json' (req, res) ->
        { alias } = req.params
        book = aliases |> find (.alias is alias)
        unless book
          return res.status 404 .send 'Not Found'
        { id, hash } = book
        request do
          "#api-host/Epub/getBookFile/#id/#hash/audio.vtt"
          (e, r, body) ->
            body .= replace /\ufeff/g
            body .= replace /\r\n?|\n/g, '\\n'
            res
              .type \json
              .send "{\"webvtt\":\"#body\"}"
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
