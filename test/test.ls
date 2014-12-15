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
  samples =
    * path: path.resolve pwd, 'sample-0.odp'
    * path: path.resolve pwd, 'sample-1.odp'

  before (done) ->
    service.start done

  describe '/' (,) ->
    it 'should have value' (done) ->
      request.get "#host/" (res) ->
        res.text.should.be.exactly 'hello world'
        done!

  describe '/books/' (,) ->
    it 'should accept a odp file' (done) ->
      @timeout 300000ms
      request
        .post "#host/books/"
        .attach 'presentation', samples.0.path
        .end (res) ->
          res.body['sample-0.odp']should.be.exactly 'd83e46e21443f2e7a0b78a5a46e4c74b3e9219cd'
          done!

    it 'should accept another odp file' (done) ->
      @timeout 800000ms
      request
        .post "#host/books/"
        .attach 'presentation', samples.1.path
        .end (res) ->
          res.body['sample-1.odp']should.be.exactly 'e4d965f7726e4e6dbe62ad7eaa036d25565df1d0'
          done!

    it 'should return the aliases of all books' (done) ->
      request
        .get "#host/books/"
        .end (res) ->
          res.body['sample-0.odp']should.be.exactly 'd83e46e21443f2e7a0b78a5a46e4c74b3e9219cd'
          res.body['sample-1.odp']should.be.exactly 'e4d965f7726e4e6dbe62ad7eaa036d25565df1d0'
          done!

    it 'should remember aliases after service restarted' (done) ->
      service.stop -> service.start ->
        request
          .get "#host/books/"
          .end (res) ->
            res.body['sample-0.odp']should.be.exactly 'd83e46e21443f2e7a0b78a5a46e4c74b3e9219cd'
            res.body['sample-1.odp']should.be.exactly 'e4d965f7726e4e6dbe62ad7eaa036d25565df1d0'
            done!

  after (done) -> service.stop done
