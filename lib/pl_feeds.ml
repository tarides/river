(*
 * Copyright (c) 2014, OCaml.org project
 * Copyright (c) 2015 KC Sivaramakrishnan <sk826@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*)

open Syndic
open Pl_http
open Printf

(* Feeds
***********************************************************************)

type source = {
  name : string;
  url  : string
}

type feed =
  | Atom of Atom.feed
  | Rss2 of Rss2.channel
  | Broken of string (* the argument gives the reason *)

let string_of_feed = function
  | Atom _ -> "Atom"
  | Rss2 _ -> "Rss2"
  | Broken s -> "Broken: " ^ s

type contributor = {
  name  : string;
  title : string;
  url   : string;
  feed  : feed;
}

let gather_sources file_name =
  let add_feed acc line =
    try
      let i = String.index line '|' in
      let name = String.sub line 0 i in
      let url = String.sub line (i+1)
          (String.length line - i - 1) in
      {name;url} :: acc
    with Not_found -> acc in
  List.fold_left add_feed [] (Pl_utils.lines_of_file file_name)

let classify_feed ~xmlbase (xml: string) =
  try Atom(Atom.parse ~xmlbase (Xmlm.make_input (`String(0, xml))))
  with Atom.Error.Error _ ->
          try Rss2(Rss2.parse ~xmlbase (Xmlm.make_input (`String(0, xml))))
          with Rss2.Error.Error _ ->
                Broken "Neither Atom nor RSS2 feed"

let contributor_of_source (source : source) =
  try
    let xmlbase = Uri.of_string @@ source.url in
    let feed = classify_feed ~xmlbase (Pl_http.get source.url) in
    let title = match feed with
    | Atom atom -> Pl_utils.string_of_text_construct atom.Atom.title
    | Rss2 ch -> ch.Rss2.title
    | Broken _ -> "" in
    { name = source.name; title; feed; url = source.url}
  with
  | Status_unhandled s | Failure s ->
      { name = source.name; title=""; feed = Broken s;
        url = source.url }
  | Timeout ->
      { name = source.name; title=""; feed = Broken "Timeout";
        url = source.url }

