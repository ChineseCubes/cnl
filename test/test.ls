require! {
  fs
  path
  should
  superagent: request
  '../src/codepoints': codepoints
  '../src/moedict':    moedict
}

service = require '../lib'
pwd     = __dirname
host    = 'http://localhost:8081'

describe 'utils' (,) ->
  describe 'codepoints' (,) ->
    it 'should separate codepoints' (done) ->
      codepoints do
        '"text":"\\u6211\\u60f3"}]}]}]}'
        (cpts) ->
          cpts.0.should.be.exactly \60f3
          cpts.1.should.be.exactly \6211
          done!

  describe 'moedict' (,) ->
    it 'should fetch data from http://www.moedict.tw/' (done) ->
      moedict do
        '萌典'
        (dict) ->
          dict['萌']should.containDeep do
            en:
              * "to sprout"
              * "to bud"
              * "to have a strong affection for (slang)​"
              * "adorable (loanword from Japanese <a href=\"#~萌\">萌</a>え moe"
              * " slang describing affection for a cute character)​"
            pinyin: "méng"
            "zh-CN": "萌"
            "zh-TW": "萌"
          dict['典']should.containDeep do
            en:
              * "canon"
              * "law"
              * "standard work of scholarship"
              * "literary quotation or allusion"
              * "ceremony"
              * "to be in charge of"
              * "to mortgage or pawn"
            pinyin: "diǎn"
            "zh-CN": "典"
            "zh-TW": "典"
          done!

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

    it 'should return the first page of that book' (done) ->
      request
        .get "#host/books/sample-0.odp/page1.json"
        .set \Accept 'application/json'
        .end (res) -> res.status.should.be.exactly 200 and done!

    it 'should return the cover image of that book' (done) ->
      request
        .get "#host/books/sample-0.odp/Pictures/100002010000040000000300E3ED7A2E.png"
        .end (res) -> res.status.should.be.exactly 200 and done!

    it 'should return the dictionary of that book' (done) ->
      request
        .get "#host/books/sample-0.odp/dict.json"
        .end (res) -> res.status.should.be.exactly 200 and done!

    it 'should return the audio of that book' (done) ->
      request
        .get "#host/books/sample-0.odp/audio.mp3.json"
        .end (res) -> res.status.should.be.exactly 200 and done!

    it 'should return the text track of that book' (done) ->
      request
        .get "#host/books/sample-0.odp/audio.vtt.json"
        .end (res) -> res.status.should.be.exactly 200 and done!

    it 'should fail when the page does not exist' (done) ->
      request
        .get "#host/books/sample-0.odp/page0.json"
        .end (res) -> res.status.should.be.exactly 404 and done!

  describe 'persistence' (,) ->
    it 'should remember aliases after service restarted' (done) ->
      @timeout 5000ms
      service.stop -> service.start ->
        request
          .get "#host/books/"
          .end (res) ->
            res.body['sample-0.odp']should.be.exactly '84fba4f60905d963338ac7285f34da744e5ead2c'
            res.body['sample-1.odp']should.be.exactly 'e4d965f7726e4e6dbe62ad7eaa036d25565df1d0'
            done!

  after (done) -> service.stop done
