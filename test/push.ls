#!/usr/bin/env lsc
require! {
  path
  superagent: request
}

host = 'http://cnl.linode.caasih.net'
#host = 'http://localhost:8081'

sample =
  path:   path.resolve 'sample-0.odp'
  mp3:    path.resolve 'sample-0.mp3'
  webvtt: path.resolve 'sample-0.vtt'

request
  .post "#host/books"
  .attach 'presentation', sample.path
  .end (res) ->
    console.log res.body
    request
      .post "#host/books/sample-0.odp/audio.mp3"
      .attach 'mp3', sample.mp3
      .end (res) -> console.log res.text
    request
      .post "#host/books/sample-0.odp/audio.vtt"
      .attach 'webvtt', sample.webvtt
      .end (res) -> console.log res.text
