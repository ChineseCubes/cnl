# v1
module.exports = ->
  name: \frame
  namespace: \draw
  attrs:
    x: '2.45cm'
    y: '17.85cm'
    width:  '23.1cm'
    height: '2.275cm'
  children:
    * name: \frame
      namespace: \draw
      id: 'glossary'
      attrs:
        x: '0cm'
        y: '0cm'
        width:  '7.35cm'
        height: '2.275cm'
        lineHeight: '2.275cm'
        fontSize: '1.1cm'
      children: []
    * name: \frame
      namespace: \draw
      id: 'read-to-me'
      attrs:
        x: '7.875cm'
        y: '0cm'
        width:  '7.35cm'
        height: '2.275cm'
        lineHeight: '2.275cm'
        fontSize: '1.1cm'
      children: []
    * name: \frame
      namespace: \draw
      id: 'learn-by-myself'
      attrs:
        x: '15.75cm'
        y: '0cm'
        width:  '7.35cm'
        height: '2.275cm'
        lineHeight: '2.275cm'
        fontSize: '1.1cm'
      children: []
