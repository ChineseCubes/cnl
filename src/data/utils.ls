require! {
  'prelude-ls': { split, map, join, reverse }
}

trim         = -> it.trim!
unslash      = -> it.replace /\/$/ '' # FIXME: should use path.normalize
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
ps-noto-name = ->
  it.replace do
    /Noto Sans ([S|T]) Chinese\s?(\w+)?/g
    (, form, style) ->
      "NotoSansHan#{form.toLowerCase!}#{if style then "-#style" else ''}"

module.exports = {
  unslash
  hyphenate
  camelize
  namesplit
  ps-noto-name
}
