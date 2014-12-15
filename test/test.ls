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
      @timeout 60000ms
      request
        .post "#host/books/"
        .attach 'presentation', samples.0.path
        .end (res) ->
          res.body['sample-0.odp']should.be.exactly '84fba4f60905d963338ac7285f34da744e5ead2c'
          done!

    it 'should accept another odp file' (done) ->
      @timeout 60000ms
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
          res.body['sample-0.odp']should.be.exactly '84fba4f60905d963338ac7285f34da744e5ead2c'
          res.body['sample-1.odp']should.be.exactly 'e4d965f7726e4e6dbe62ad7eaa036d25565df1d0'
          done!

    it 'should remember aliases after service restarted' (done) ->
      @timeout 5000ms
      service.stop -> service.start ->
        request
          .get "#host/books/"
          .end (res) ->
            res.body['sample-0.odp']should.be.exactly '84fba4f60905d963338ac7285f34da744e5ead2c'
            res.body['sample-1.odp']should.be.exactly 'e4d965f7726e4e6dbe62ad7eaa036d25565df1d0'
            done!

  describe '/books/sample-0.odp/' (,) ->
    it 'should return a valid metadata' (done) ->
      request
        .get "#host/books/sample-0.odp/"
        .set \Accept 'application/json'
        .end (res) ->
          {
            contributors, coverage,   creator,  date,      description,
            format,       identifier, language, publisher, relation,
            rights,       source,     subject,  title,     type,
            'rendition:layout': layout
            'rendition:spread': spread
          } = res.body
          (contributors isnt undefined)should.be.true
          (coverage     isnt undefined)should.be.true
          (creator      isnt undefined)should.be.true
          (description  isnt undefined)should.be.true
          (format       isnt undefined)should.be.true
          (identifier   isnt undefined)should.be.true
          (language     isnt undefined)should.be.true
          (publisher    isnt undefined)should.be.true
          (relation     isnt undefined)should.be.true
          (rights       isnt undefined)should.be.true
          (source       isnt undefined)should.be.true
          (subject      isnt undefined)should.be.true
          (title        isnt undefined)should.be.true
          (type         isnt undefined)should.be.true
          (layout       isnt undefined)should.be.true
          (spread       isnt undefined)should.be.true
          done!

  after (done) -> service.stop done
