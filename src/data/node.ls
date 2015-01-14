require! {
  './utils': { strip, camelize, namesplit }
  '../tmpl/menu':        menu
  '../tmpl/play-button': play-button
}

###
# traverse
traverse = (node, onEnter, onLeave, parents = []) !->
  | not node                 => return
  | not (onEnter or onLeave) => return
  | otherwise
    onEnter? node, parents
    namelist = if node.name then [node.name] else []
    for child in (node.children or [])
      traverse child, onEnter, onLeave, parents.concat namelist
    onLeave? node, parents
###
# transform
##
# onNode should return a new object here.
transform = (node, onNode, parents = []) ->
  | not node   => return
  | otherwise
    new-node = if onNode
      then onNode node, parents
      else {}
    namelist = if node.name then [node.name] else []
    new-node.children = for child in (node.children or [])
      transform child, onNode, parents.concat namelist
    new-node

###
# Patch the Presentation
###

###
# v1-from-v0
##
# patch a presentation from the v0 format(parsed by the PHP server) to my
# internal format for react-odp
v1-from-v0 = (node, path = '') ->
  prop-names = <[name className href pageNum onClick onTouchStart]>
  name = node.attrs['DRAW:NAME']
  if name isnt \page1
    idx = +name.replace('page', '') - 1
    node.children.push play-button idx
  node = transform node, (n, ps) ->
    attrs = style: {}
    for k, v of n.attrs
      name = camelize namesplit(k)name
      switch
      | name is \x          => attrs.style.left   = v
      | name is \y          => attrs.style.top    = v
      | name is \pageWidth  => attrs.style.width  = v
      | name is \pageHeight => attrs.style.hegiht = v
      | name is \href       => attrs.href         = "#path/#v"
      | name in prop-names  => attrs[name]        = v
      | otherwise           => attrs.style[name]  = v
    # vertical-align
    if attrs.style.textarea-vertical-align
      aligned = attrs.style.textarea-vertical-align
      traverse n, (n, ps) ->
        if n.name is /TEXT-BOX|IMAGE/
          n.attrs['class-name'] = "aligned #aligned"
    namesplit(n.name) <<<
      text:  n.text
      attrs: attrs
  if name is \page1
    node.children.push menu!
  node

###
# v1-sentences
##
# get all sentences of the page
v1-sentences = (node) ->
  sentences = []
  traverse do
    node
    (n, ps) ->
      if (n.name is \span)  and
         not (\notes in ps) and
         n.text
        sentences.push n.text
  sentences

###
# v1-segments
##
# get all words of the page
v1-segments = (node) ->
  var sgmnt
  state = \zh
  segments = []
  traverse do
    node
    (n, ps) ->
      if (n.name is \span) and
         (\notes in ps)    and
         n.text
        sgmnt := {} if not sgmnt
        sgmnt[state] = n.text
    (n, ps) ->
      if (n.name is \span) and
         (\notes in ps)    and
         n.text
        if state is \en
          segments.push sgmnt
          sgmnt := null
          state := \zh
        else
          state := \en
  segments

v1-dicts = (node) ->
  dicts = []
  traverse do
    node
    (n, ps) ->
      if (n.attrs.data)
        dicts :=
          for d in n.attrs.data
            'zh-TW': d.traditional
            'zh-CN': d.simplified
            pinyin:  d.pinyin_marks
            en:      strip d.translation .split /\//
  dicts

###
# v2-from-v1
##
# patch a presentation from v1 to the new format(v2) for online editor
v2-from-v1 = (node) -> ... # XXX: unimplemented

module.exports = {
  traverse
  transform
  v1-from-v0
  v1-sentences
  v1-segments
  v1-dicts
}
