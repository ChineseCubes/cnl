require! {
  should
  superagent: request
}

service = require '../lib'

describe 'API endpoints', (,) ->

  before (done) -> service.start done

  describe '/', (,) ->
    it 'should have value' (done) ->
      request.get 'http://localhost:8081/' (res) ->
        res.text.should.be.exactly 'hello world'
        done!

  after (done) -> service.stop done
