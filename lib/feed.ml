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

type source = { name : string; url : string }
type content = Atom of Syndic.Atom.feed | Rss2 of Syndic.Rss2.channel

let string_of_feed = function Atom _ -> "Atom" | Rss2 _ -> "Rss2"

type t = { name : string; title : string; url : string; content : content }

(* HTML void elements: they have no content and, in HTML, need no closing
   tag. In XML (and hence in Atom [type="xhtml"] content) they must be
   self-closed. *)
let void_elements =
  "area\\|base\\|br\\|col\\|embed\\|hr\\|img\\|input\\|link\\|meta\\|param\\|source\\|track\\|wbr"

let void_pair_re =
  Str.regexp_case_fold ("<\\(" ^ void_elements ^ "\\)\\([^>]*\\)></\\1[ \t\r\n]*>")

let void_open_re =
  Str.regexp_case_fold ("<\\(" ^ void_elements ^ "\\)\\([^>]*\\)>")

(* Postel's-law repair for "almost-XHTML" feeds.

   Some feeds declare [<content type="xhtml">] — which RFC 4287 requires to be
   well-formed XML — yet embed HTML void elements that are either left
   unclosed ([<img ...>]) or closed with a redundant end tag
   ([<img ...></img>]). A strict XML parser (xmlm, and therefore Syndic) then
   rejects the whole feed. [sanitize_void_elements] rewrites both shapes into
   the self-closing form so the document becomes well-formed.

   It is deliberately conservative: it only touches the known HTML void
   elements, and only their raw, unescaped occurrences — escaped
   [type="html"] content has no literal '<', so it is never affected. *)
let sanitize_void_elements (xml : string) : string =
  (* Pass 1: [<img ...></img>] -> [<img ... />] (drop the redundant end tag). *)
  let xml =
    Str.global_substitute void_pair_re
      (fun s ->
        Printf.sprintf "<%s%s />" (Str.matched_group 1 s) (Str.matched_group 2 s))
      xml
  in
  (* Pass 2: bare [<img ...>] -> [<img ... />], leaving already self-closed
     elements untouched. *)
  Str.global_substitute void_open_re
    (fun s ->
      let attrs = String.trim (Str.matched_group 2 s) in
      if attrs <> "" && attrs.[String.length attrs - 1] = '/' then
        Str.matched_string s
      else
        Printf.sprintf "<%s%s />" (Str.matched_group 1 s) (Str.matched_group 2 s))
    xml

let classify_feed ~xmlbase ?(repair = false) (xml : string) =
  let parse xml =
    try Atom (Syndic.Atom.parse ~xmlbase (Xmlm.make_input (`String (0, xml))))
    with Syndic.Atom.Error.Error _ ->
      Rss2 (Syndic.Rss2.parse ~xmlbase (Xmlm.make_input (`String (0, xml))))
  in
  try parse xml
  with Syndic.Atom.Error.Error _ | Syndic.Rss2.Error.Error _ ->
    (* Not well-formed as-is. Only retry a repaired copy when explicitly asked
       to, so well-formed feeds are never modified and the default behaviour is
       unchanged. *)
    if not repair then failwith "Neither Atom nor RSS2 feed"
    else (
      try parse (sanitize_void_elements xml)
      with Syndic.Atom.Error.Error _ | Syndic.Rss2.Error.Error _ ->
        failwith "Neither Atom nor RSS2 feed")

let of_string ?repair (source : source) (xml : string) =
  let xmlbase = Uri.of_string @@ source.url in
  let content = classify_feed ~xmlbase ?repair xml in
  let title =
    match content with
    | Atom atom -> Util.string_of_text_construct atom.Syndic.Atom.title
    | Rss2 ch -> ch.Syndic.Rss2.title
  in
  { name = source.name; title; content; url = source.url }

let fetch ?timeout ?user_agent ?repair (source : source) =
  let response = Http.get ?timeout ?user_agent source.url in
  of_string ?repair source response
