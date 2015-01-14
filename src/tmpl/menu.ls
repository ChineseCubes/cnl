# v1
module.exports = ->
  name: \frame
  namespace: \draw
  attrs:
    style:
      left: '2.45cm'
      top:  '17.85cm'
      width:  '23.1cm'
      height: '2.275cm'
  children:
    * name: \glossary
      namespace: \menu
      attrs:
        style:
          left: '0cm'
          top:  '0cm'
          width:  '7.35cm'
          height: '2.275cm'
          lineHeight: '2.275cm'
          fontSize: '1.1cm'
      children: []
    * name: \read-to-me
      namespace: \menu
      attrs:
        style:
          left: '7.875cm'
          top:  '0cm'
          width:  '7.35cm'
          height: '2.275cm'
          lineHeight: '2.275cm'
          fontSize: '1.1cm'
      children: []
    * name: \learn-by-myself
      namespace: \menu
      attrs:
        style:
          left: '15.75cm'
          top:  '0cm'
          width:  '7.35cm'
          height: '2.275cm'
          lineHeight: '2.275cm'
          fontSize: '1.1cm'
      children: []
