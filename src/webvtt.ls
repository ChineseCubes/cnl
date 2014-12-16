#!/usr/bin/env lsc
require! {
  fs
  path
}

running-as-script = not module.parent

webvtt = (path-vtt, done) ->
  err, vtt <- fs.readFile path-vtt
  throw err if err
  vtt .= toString!
  vtt .= replace /\ufeff/g, ''
  vtt .= replace /\r\n?|\n/g, '\\n'
  done "{\"webvtt\":\"#vtt\"}"

if running-as-script
  { 2: path-vtt } = process.argv
  webvtt do
    path.resolve path-vtt
    console.log
else
  module.exports = webvtt
