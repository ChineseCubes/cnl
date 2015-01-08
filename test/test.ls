require! {
  fs
  path
  should
  superagent: request
  '../src/codepoints': codepoints
  '../src/moedict':    moedict
  '../src/webvtt':     webvtt
  '../src/data/utils':
    { unslash, hyphenate, camelize, namesplit, ps-noto-name }
  '../src/data/node':
    { traverse, transform, v1-from-v0, v1-sentences, v1-segments, v1-dicts }
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

  describe 'unslash' (,) ->
    it 'should remove last /' ->
      unslash 'foobar/' .should.be.exactly 'foobar'

  describe 'hyphenate' (,) ->
    it 'should split words with -' ->
      hyphenate '' .should.be.exactly ''
      hyphenate 'fOo Bar' .should.be.exactly 'foo-bar'
      hyphenate 'foo - bar' .should.be.exactly 'foo---bar'

  describe 'camelize' (,) ->
    it 'should camelize and concat words' ->
      camelize '' .should.be.exactly ''
      camelize '  foo  bar' .should.be.exactly 'fooBar'
      camelize 'foo-bar  ' .should.be.exactly 'fooBar'

  describe 'namesplit' (,) ->
    it 'should split the name with namespace' ->
      { namespace, name } = namesplit 'FOO:BAR'
      namespace.should.be.exactly 'foo'
      name.should.be.exactly 'bar'
      { namespace, name } = namesplit 'bar'
      should namespace .be.not.ok
      name.should.be.exactly 'bar'

  describe 'ps-noto-name' (,) ->
    it 'should give the postscript name of a Noto Sans Chinese font' ->
      ps-noto-name 'Noto Sans T Chinese'
        .should.be.exactly 'NotoSansHant'
      ps-noto-name 'Noto Sans T Chinese Regular'
        .should.be.exactly 'NotoSansHant-Regular'
      ps-noto-name 'Noto Sans S Chinese Regular'
        .should.be.exactly 'NotoSansHans-Regular'

describe 'node(page of a presentation)' (,) ->
  node =
    name: \foo
    props:
      type: \first
    children:
      * name: \bar
        props:
          type: \child
        children: []
      * name: \foobar
        props:
          type: \child
        children:
          * name: \quux
            props:
              type: \last
            children: []
          ...

  describe 'traverse' (,) ->
    it 'should visit all nodes' ->
      stack = []
      traverse do
        node
        (n, ps) !->
          stack.push do
            name:    n.name
            type:    n.props.type
            parents: ps
        (n, ps) !->
          { name, type, parents } = stack.pop!
          n.name.should.be.eql name
          n.props.type.should.be.eql type
          ps.should.be.eql parents

  describe 'transform' (,) ->
    it 'should create a new tree' ->
      new-node = transform node, (n, ps) ->
        name: n.name.toUpperCase!
      count = 0
      traverse new-node, (n, ps) !->
        | count is 0 => n.name.should.be.eql \FOO
        | count is 1 => n.name.should.be.eql \BAR
        | count is 2 => n.name.should.be.eql \FOOBAR
        | count is 3 => n.name.should.be.eql \QUUX
        ++count

    it 'should return the skeleton' ->
      new-node = transform node
      new-node.should.not.be.eql node
      count = 0
      traverse new-node, (n, ps) !->
        | count is 0 => n.children.length.should.be.eql 2
        | count is 1 => n.children.length.should.be.eql 0
        | count is 2 => n.children.length.should.be.eql 1
        | count is 3 => n.children.length.should.be.eql 0
        ++count

  page = v1-from-v0 require './haoaidu.json'
  describe 'v1 page' (,) ->
    it 'should have sentences' ->
      v1-sentences page .should.be.eql <[ 大家好。 我是好愛讀。 ]>

    it 'should have segments' ->
      v1-segments page .should.be.eql [
        { zh: '大家好',     en: 'Hello everyone. '       }
        { zh: '我是好愛讀', en: 'My name is Hao ai du. ' }
      ]

    it 'should dave dicts' ->
      # XXX: should test more
      v1-dicts page .length.should.be.exactly 12

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
