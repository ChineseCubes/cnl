require! {
  'prelude-ls': { split, map, join, reverse }
}

trim         = -> it.trim!
unslash      = -> it.replace /\/$/    '' # FIXME: should use path.normalize
strip        = -> it.replace /<.*?>/g ''
hyphenate    = ->
  it
  |> trim
  |> split ' '
  |> map (.toLowerCase!)
  |> join '-'
camelize     = ->
  it .= trim!
  x = it?0?toLowerCase! or ''
  it = it
  |> split /-| /
  |> map (v, i) -> "#{v.slice(0, 1)toUpperCase!}#{v.slice(1)}"
  |> join ''
  "#x#{it.slice(1)}"
namesplit    = ->
  r = it.toLowerCase! |> split ':' |> reverse
  namespace: r.1
  name:      r.0
noto-fallbacks = ->
  result = /Noto Sans ([S|T]) Chinese\s?(\w+)?|Noto Sans CJK ([S|T])C\s?(\w+)?/.exec it
  if result
    [ , form0 = '', style0 = '', form1 = '', style1 = '' ] = result
    #style or= ''
    fallbacks:
      * "Noto Sans #{form0 or form1} Chinese"
      * "Noto Sans CJK #{form0 or form1}C"
    weight: if style0 is 'Bold' or style1 is 'Bold' then 'bold' else 'normal'
  else
    fallbacks: []
    weight: 'normal'


module.exports = {
  unslash
  hyphenate
  camelize
  namesplit
  noto-fallbacks
  strip
}
