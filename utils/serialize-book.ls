#!/usr/bin/env lsc
require! {
  request
  rsvp: { Promise, all }:RSVP
  'prelude-ls': { flatten }
}

RSVP.on \error console.log

host = 'http://cnl.linode.caasih.net'
running-as-script = not module.parent

get-masterpage = (alias) -> new Promise (resolve, reject) ->
  request do
    "#host/books/#alias/masterpage.json"
    (e, r, body) ->
      if e
        then reject e
        else resolve JSON.parse body

get-page = (alias, id) -> new Promise (resolve, reject) ->
  request do
    "#host/books/#alias/page#id.json"
    (e, r, body) ->
      if e
        then reject e
        else resolve JSON.parse body

flat-node = (node) ->
  children = node.children or []
  delete node.children
  flatten [node, (for c in children => flat-node c)]

serialize-book = (alias) ->
  get-masterpage alias
    .then (mp)    -> mp.attrs['TOTAL-PAGES']
    .then (total) -> all (for i from 1 to total => get-page alias, i)
    .then (pages) -> flatten (for p in pages => flat-node p)

if running-as-script
  [,, ...books] = process.argv
  for alias in books
    serialize-book alias .then ->
      console.log JSON.stringify it, null, 2
else
  module.exports = serialize-book

