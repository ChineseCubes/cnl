#!/usr/bin/env lsc
# XXX: This file should be merged to the source repo later.
require! through

running-as-script = not module.parent

re = /\\u([a-f0-9]+)/ig

codepoints = (str, done) ->
  cpts = {}
  while re.exec str => cpts["#{RegExp.$1}"] := true
  done Object.keys(cpts)sort!

if running-as-script
  todo = ''
  process.stdin
    .pipe through do
      -> todo += it
      -> @queue codepoints todo, (.join "\n")
    .pipe process.stdout
else
  module.exports = codepoints
