require! {
  fs
  path
  should
  superagent: request
}

service = require '../lib'
pwd     = __dirname
host    = 'http://localhost:8081'

describe 'API endpoints' (,) ->
  sample =
    stat: null
    path: path.resolve pwd, 'sample.odp'

  before (done) ->
    sample.stat := fs.statSync sample.path
    service.start done

  describe '/' (,) ->
    it 'should have value' (done) ->
      request.get "#host/" (res) ->
        res.text.should.be.exactly 'hello world'
        done!

  describe '/books/' (,) ->
    it 'should accept an odp file' (done) ->
      request
        .post "#host/books/"
        .attach 'presentation', sample.path
        .end (res) ->
          res.body.size.should.be.exactly sample.stat.size
          done!

  after (done) -> service.stop done
