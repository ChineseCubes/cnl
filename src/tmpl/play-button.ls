# v0
module.exports = (idx) ->
  name: 'draw:frame'
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

