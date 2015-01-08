require! {
  './utils': { camelize, namesplit }
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
# create-play-button
create-play-button = (idx) ->
  * name: 'draw:frame'
    attrs:
      'style-name': \Mgr4
      'text-style-name': \MP4
      x:      \25.16cm
      y:      \1.35cm
      width:  \1.458cm
      height: \1.358cm
    children:
      * name: 'draw:image'
        attrs:
          name: \activity
          'page-num': idx
          'on-click': -> ...
          'font-size': '1cm'
        ...
    ...

###
# v1-from-v0
##
# patch a presentation from the v0 format(parsed by the PHP server) to my
# internal format for react-odp
v1-from-v0 = (node, path = '') ->
  prop-names = <[name x y width height href data onClick onTouchStart]>
  name = node.attrs['DRAW:NAME']
  if name isnt \page1
    idx = +name.replace('page', '') - 1
    node.children = node.children.concat create-play-button idx
  transform node, (n, ps) ->
    attrs = style: {}
    for k, v of n.attrs
      name = camelize namesplit(k)name
      switch
      | name is 'pageWidth'  => attrs.width       = v
      | name is 'pageHeight' => attrs.hegiht      = v
      | name in prop-names   => attrs[name]       = v
      | name is 'pageNum'    => attrs[name]       = v
      | otherwise            => attrs.style[name] = v
    attrs.href = "#path/#{attrs.href}" if attrs.href
    namesplit(n.name) <<<
      text:  n.text
      attrs: attrs

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
}
