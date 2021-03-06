#!/usr/bin/env lsc
require! {
  request
  rsvp: { Promise, all }:RSVP
  'prelude-ls': { concat }
}

RSVP.on \error console.error

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

current-id = 0
flat-node = (node) ->
  node.id = current-id++
  children = node.children or []
  nss = for children => flat-node ..
  node.children = for ns in nss => ns.0.id
  [node]concat concat nss

serialize-book = (alias) ->
  get-masterpage alias
    .then (mp)    -> mp.attrs['TOTAL-PAGES']
    .then (total) -> all (for [1 to total] => get-page alias, ..)
    .then (pages) -> concat (for pages => flat-node ..)

if running-as-script
  [,, ...books] = process.argv
  for alias in books
    serialize-book alias .then ->
      console.log JSON.stringify it, null, 2
else
  module.exports = serialize-book

