#!/usr/bin/env lsc
require! {
  path
  superagent: request
}

host = 'http://cnl.linode.caasih.net'
#host = 'http://localhost:8081'

push = (book) ->
  sample =
    path:   path.resolve "#book.odp"
    mp3:    path.resolve "#book.mp3"
    webvtt: path.resolve "#book.vtt"
  request
    .post "#host/books"
    .attach 'presentation', sample.path
    .end (res) ->
      console.log res.body
      request
        .post "#host/books/#book.odp/audio.mp3"
        .attach 'mp3', sample.mp3
        .end (res) -> console.log res.text
      request
        .post "#host/books/#book.odp/audio.vtt"
        .attach 'webvtt', sample.webvtt
        .end (res) -> console.log res.text

[,,...pathes] = process.argv
pathes.map push
