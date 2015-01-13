require! {
  fs
  express
  request
  cors
  moment
  winston
  rsvp:         { Promise, all }:RSVP
  'prelude-ls': { filter, find }
  './codepoints':    codepoints
  './moedict':       moedict
  './tmpl/contents': contents
  './data/utils': { hyphenate }
  './data/node' : { v1-from-v0 }
}

###
# logger
logger = new winston.Logger do
  levels:
    debug:   0
    info:    1
    server:  1
    request: 1
    warn:    2
    error:   3
  colors:
    debug:   \blue
    info:    \green
    server:  \magenta
    request: \cyan
    warn:    \yellow
    error:   \red
  transports:
    * new winston.transports.Console do
        colorize:  on
        timestamp: on
    * new winston.transports.File do
        timestamp: on
        filename:  'cnl.log'

###
# configs
#aliases-db  = level './db/aliases'
api-host    = 'https://apis-beta.chinesecubes.com'
not-running = (done) !-> done? new Error 'server is not running'

RSVP.on \error -> logger.error it

###
# helpers
running-as-script = not module.parent

generate-dict = ({ id, hash, alias }) -> new Promise (resolve, reject) ->
  return resolve null # uncomment to disable dict.json
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
          logger.server "/books/#alias/dict.json"
          resolve moedict chars

Books =
  aliases: []
  dicts:   {}
  find:     (alias) -> @aliases |> find (.alias is alias)
  findById: (id)    -> @aliases |> find (.id is id) # FIXME: slow?
  init: -> new Promise (resolve, reject) ~>
    logger.server "init books"
    request do
      "#api-host/Epub/getBooklist"
      (e, r, body) ~>
        | e                     => reject e
        | r.statusCode isnt 200 => reject new Error "status: #{r.statusCode}"
        | otherwise
          for book in JSON.parse body
            book <<<
              id:        +book.id
              alias:     hyphenate book.title
              timestamp: moment book.last_update .valueOf!
            @aliases.push book
          @aliases.sort (a, b) -> a.id - b.id
          ps = for let book in Books.aliases
            logger.server "update book: ", book
            @dicts[book.alias] = generate-dict book
          resolve ps
  update: -> new Promise (resolve, reject) ~>
    logger.server "update books"
    request do
      "#api-host/Epub/getBooklist"
      (e, r, body) ~>
        | e                     => reject e
        | r.statusCode isnt 200 => reject new Error "status: #{r.statusCode}"
        | otherwise
          ps = for book in JSON.parse body
            book <<<
              id:        +book.id
              alias:     hyphenate book.title
              timestamp: moment book.last_update .valueOf!
            old = @findById book.id
            if old           is   undefined      or
               old.hash      isnt book.hash      or
               old.timestamp isnt book.timestamp
              old <<< book
              @dicts[old.alias] = generate-dict old
            @dicts[old.alias]
          resolve ps

ask-apis-beta = (alias, filepath, req, res) ->
  book = Books.find alias
  unless book
    return res.status 404 .send 'Not Found'
  { id, hash } = book
  #if filepath is /page([1-9]\d?)\.json$/
  #  page-num = +RegExp.$1
  #  if page-num is 2
  #    return res.json contents!
  #  if page-num > 2
  #    filepath .= replace "page#page-num.json" "page#{page-num - 1}.json"
  request do
    method:   \GET
    url:      "#api-host/Epub/getBookFile/#id/#hash/#filepath"
    encoding: \binary
    (e, r, body) !-> # prevent switch return
      if e
        return res.sendStatus 500
      if r.statusCode isnt 200
        return res.sendStatus r.statusCode
      if body.length is 0
        return res.sendStatus 404
      switch
      # patch the page on the fly
      | filepath is /page([1-9]\d?)\.json$/
        res.json v1-from-v0 do
          JSON.parse body
          "http://#{req.headers.host}/books/#alias"
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
      | filepath is /.mp3$/
        res
          ..type 'mp3'
          ..send new Buffer body, \binary
      | otherwise
        res
          ..send 'text'
          ..send body

service =
  msg:   'you have control'
  stop:  not-running
  start: (done) !->
    start = !->
      (app = express!)
        #.use multer dest: path.resolve 'uploads'
        .use cors!
        .use (req, res, next) ->
          logger.request req.originalUrl
          next!
        .get '/' (req, res) ->
          res.send service.msg
        .get '/logs/' (req, res) ->
          logger.query do
            from:  0
            until: moment!
            (err, msgs) ->
              if err
                then res.sendStatus 500
                else res.json msgs.file
        .get '/logs/:level' (req, res) ->
          { level } = req.params
          logger.query do
            from:  0
            until: moment!
            (err, msgs) ->
              if err
                then res.sendStatus 500
                else res.json filter (.level is level), msgs.file
        .get '/books/' (req, res) ->
          res.send Books.aliases
        .get '/books/:alias/' (req, res) ->
          { alias } = req.params
          ask-apis-beta alias, 'masterpage.json', req, res
        .get '/books/:alias/dict.json' (req, res) ->
          { alias } = req.params
          book = Books.find alias
          unless book
            return res.status 404 .send 'Not Found'
          Books.dicts[alias]then -> res.json it
        .put '/books/:alias/dict.json' (req, res) ->
          { alias } = req.params
          book = Books.find alias
          unless book
            return res.status 404 .send 'Not Found'
          (Books.dicts[alias] = generate-dict book)then -> res.send it
        .get '/books/:alias/audio.mp3.json' (req, res) ->
          { alias } = req.params
          book = Books.find alias
          unless book
            return res.status 404 .send 'Not Found'
          { id, hash } = book
          request do
            method:   \GET
            url:      "#api-host/Epub/getBookFile/#id/#hash/audio.mp3"
            encoding: \binary
            (e, r, body) ->
              base64 = new Buffer(body, \binary)toString(\base64)
              res
                .type \json
                .send "{\"mp3\":\"data:audio/mp3;base64,#base64\"}"
        .get '/books/:alias/audio.vtt.json' (req, res) ->
          { alias } = req.params
          book = Books.find alias
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
          logger.server "listening at http://#address:#port" if running-as-script
          done?!

    Books.init!then ->
      start!
      interval = 60000ms
      update = ->
        Books.update!then -> all it .then -> setTimeout update, interval
      all it .then -> setTimeout update, interval

if running-as-script
  then service.start!
  else module.exports = service
