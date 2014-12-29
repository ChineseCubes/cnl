require! {
  fs
  path
  should
  superagent: request
  '../src/codepoints': codepoints
  '../src/moedict':    moedict
  '../src/webvtt':     webvtt
}

service = require '../lib'
pwd     = __dirname
host    = 'http://localhost:8081'

describe 'utils' (,) ->
  describe 'codepoints' (,) ->
    it 'should separate codepoints' (done) ->
      codepoints '{"text":"\\u6211\\u60f3"}' .then (cpts) ->
        cpts.0.should.be.exactly \60f3
        cpts.1.should.be.exactly \6211
        done!

  describe 'moedict' (,) ->
    it 'should fetch data from http://www.moedict.tw/' (done) ->
      moedict '萌典' .then (dict) ->
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

  describe 'webvtt' (,) ->
    it 'should return vtt.json' (done) ->
      webvtt do
        path.resolve pwd, 'sample-0.vtt'
        (str) ->
          str.should.be.exactly '{"webvtt":"WEBVTT\\n\\n1\\n00:00:00.000 --> 00:00:02.490\\n我想擁抱頑皮的猴子\\n\\n2\\n00:00:02.490 --> 00:00:05.075\\n我想擁抱懶惰的樹懶\\n\\n"}'
          done!

describe 'API endpoints' (,) ->
  samples =
    * path:   path.resolve pwd, 'sample-0.odp'
      hash:   'd527ced2aada603fd12989a39009b0cc6deb7e85'
      mp3:    path.resolve pwd, 'sample-0.mp3'
      webvtt: path.resolve pwd, 'sample-0.vtt'
    * path:   path.resolve pwd, 'sample-1.odp'
      hash:   'e6d24a19ab7a384fcf0d86c850f3de9595ba0137'
      mp3:    path.resolve pwd, 'sample-1.mp3'
      webvtt: path.resolve pwd, 'sample-1.vtt'

  before (done) ->
    service.start done

  describe '/' (,) ->
    it 'should be fine' (done) ->
      request.get "#host/" (res) ->
        res.text.should.be.exactly service.msg
        done!

  describe '/books/' (,) ->
    it 'should return all books' (done) ->
      request
        .get "#host/books/"
        .end (res) ->
          # FIXME: should add more details
          should(res.body)be.ok
          done!

  after (done) -> service.stop done
