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
open Http
open Printf

(* Utils
***********************************************************************)

(* Remove all tags *)
let rec syndic_to_buffer b = function
  | XML.Node (_, _, subs) -> List.iter (syndic_to_buffer b) subs
  | XML.Data (_, d) -> Buffer.add_string b d

let syndic_to_string x =
  let b = Buffer.create 1024 in
  List.iter (syndic_to_buffer b) x;
  Buffer.contents b

let string_of_text_construct : Atom.text_construct -> string = function
  (* FIXME: we probably would like to parse the HTML and remove the tags *)
  | Atom.Text s | Atom.Html(_,s) -> s
  | Atom.Xhtml(_, x) -> syndic_to_string x

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

let classify_feed ~xmlbase (xml: string) =
  try Atom(Atom.parse ~xmlbase (Xmlm.make_input (`String(0, xml))))
  with Atom.Error.Error _ ->
          try Rss2(Rss2.parse ~xmlbase (Xmlm.make_input (`String(0, xml))))
          with Rss2.Error.Error _ ->
                Broken "Neither Atom nor RSS2 feed"

let contributor_of_source (source : source) =
  try
    let xmlbase = Uri.of_string @@ source.url in
    let feed = classify_feed ~xmlbase (Http.get source.url) in
    let title = match feed with
    | Atom atom -> string_of_text_construct atom.Atom.title
    | Rss2 ch -> ch.Rss2.title
    | Broken _ -> "" in
    { name = source.name; title; feed; url = source.url}
  with
  | Status_unhandled s ->
      { name = source.name; title=""; feed = Broken s;
        url = source.url }
