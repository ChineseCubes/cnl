require! {
  fs
  express
  request
  cors
  moment
  rsvp:         { Promise, all }:RSVP
  'prelude-ls': { filter, split, join, map, find }
  './codepoints': codepoints
  './moedict':    moedict
}

##
# configs
#aliases-db  = level './db/aliases'
api-host    = 'https://apis-beta.chinesecubes.com'
not-running = (done) !-> done? new Error 'server is not running'

RSVP.on \error -> console.log it

###
# helpers
running-as-script = not module.parent
trim              = -> it.replace /^\s+|\s+$/, ''
hyphenated        = -> it |> trim |> split ' ' |> map (.toLowerCase!) |> join '-'


generate-dict = ({ id, hash, alias }) -> new Promise (resolve, reject) ->
  get-file = (filepath) -> new Promise (resolve, reject) ->
    request do
      "#api-host/Epub/getBookFile/#id/#hash/#filepath"
      (e, r, body) ->
        throw e if e
        return reject r unless r.statusCode is 200
        resolve body
  request do
    "#api-host/Epub/getBookFile/#id/#hash/masterpage.json"
    (e, r, body) ->
      throw e if e
      return unless r.statusCode is 200
      page-num = +JSON.parse body .attrs['TOTAL-PAGES']
      ps = for i from 1 to page-num => get-file "page#i.json"
      all ps
        .then ->
          codepoints it.join ''
        .then (cpts) ->
          cpts  = (for cpts => parseInt .., 16)
          chars = (for cpts => String.fromCharCode ..)join('')
          console.log "dict.json: #alias"
          resolve moedict chars

service =
  msg:   'you have control'
  stop:  not-running
  start: (done) !->
    aliases = []
    dicts = {}

    ask-apis-beta = (alias, filepath, req, res) ->
      book = aliases |> find (.alias is alias)
      unless book
        return res.status 404 .send 'Not Found'
      { id, hash } = book
      request do
        method:   \GET
        url:      "#api-host/Epub/getBookFile/#id/#hash/#filepath"
        encoding: \binary
        (e, r, body) !-> # prevent switch return
          if e
            return res.status 500 .send 'Internal Error'
          if r.statusCode isnt 200
            return res.status r.statusCode .send '?'
          switch
            | filepath is /.json$/
              res
                ..type 'json'
                ..send body
            | filepath is /.jpg/
              res
                ..type 'jpg'
                ..send new Buffer body, \binary
            | filepath is /.png$/
              res
                ..type 'png'
                ..send new Buffer body, \binary
            | otherwise
              res
                ..send 'text'
                ..send body

    start = !->
      (app = express!)
        #.use multer dest: path.resolve 'uploads'
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
        .put '/books/:alias/dict.json' (req, res) ->
          { alias } = req.params
          book = aliases |> find (.alias is alias)
          unless book
            return res.status 404 .send 'Not Found'
          generate-dict book .then ->
            dicts[book.alias] = it
            res.send 'Ok'
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
              body .= replace /\ufeff/g, ''
              body .= replace /\r\n?|\n/g, '\\n'
              res
                .type \json
                .send "{\"webvtt\":\"#body\"}"
        .get /\/books\/[^/]+\/.+/ (req, res) ->
          { 1: alias, 2: filepath } = /\/books\/([^/]+)\/(.+)/exec req.url
          filepath .= replace /Pictures\//, ''
          ask-apis-beta alias, filepath, req, res
      server = app.listen do
        process.env.PORT or 8081
        ->
          service.stop := (done) !->
            server.close ->
              server.stop := not-running
              done!
          { address, port } = server.address!
          console.log "listening at http://#address:#port" if running-as-script
          done?!

    ###
    # main
    request do
      "#api-host/Epub/getBooklist"
      (err, res, body) ->
        for book in JSON.parse body
          book <<<
            alias: hyphenated book.title
            timestamp: moment book.last_update .valueOf!
          aliases.push book
        aliases.sort (a, b) -> +a.id - +b.id
        for let book in aliases
          dicts[book.alias] := generate-dict book
        start!

if running-as-script
  then service.start!
  else module.exports = service
