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

(* Substring search: index of the first occurrence of [needle] in [hay] at or
   after [start], if any. *)
let find_from hay needle start =
  let hl = String.length hay and nl = String.length needle in
  let rec loop i =
    if i + nl > hl then None
    else if String.sub hay i nl = needle then Some i
    else loop (i + 1)
  in
  loop start

let entry_open_re = Str.regexp_case_fold "<entry\\([ \t\r\n][^>]*\\)?>"
let updated_tag_re = Str.regexp_case_fold "<updated[ \t\r\n/>]"

let published_elt_re =
  Str.regexp_case_fold
    "<published\\([ \t\r\n][^>]*\\)?>\\([^<]*\\)</published[ \t\r\n]*>"

let updated_elt_re =
  Str.regexp_case_fold
    "<updated\\([ \t\r\n][^>]*\\)?>\\([^<]*\\)</updated[ \t\r\n]*>"

let has_updated block =
  match Str.search_forward updated_tag_re block 0 with
  | _ -> true
  | exception Not_found -> false

(* If [block] (the children of an <entry>) contains a <published> but no
   <updated>, return [block] with an <updated> holding the published date
   inserted right after </published>. *)
let fill_from_published block =
  match Str.search_forward published_elt_re block 0 with
  | exception Not_found -> None
  | _ ->
      let v = String.trim (Str.matched_group 2 block) in
      let after = Str.match_end () in
      Some
        (String.sub block 0 after
        ^ "<updated>" ^ v ^ "</updated>"
        ^ String.sub block after (String.length block - after))

(* Semantic repair for well-formed Atom feeds that Syndic rejects because an
   <entry> has no <updated>, which RFC 4287 makes mandatory. Many generators
   emit <published> without <updated> for never-edited posts, and one such
   entry makes Syndic drop the whole feed. [repair_missing_updated] defaults a
   missing entry <updated> to, in order of preference: the entry's own
   <published>, else the feed-level <updated>. This is a semantically safe
   reconstruction — RFC 4287 defines [updated] as the last significant change,
   which for an unedited entry is its publication — and exactly the fallback
   mainstream generators (jekyll-feed, Zola, Hugo) use.

   Like [sanitize_void_elements] it is conservative and meant only for the
   [~repair] retry: it edits the raw text of the default (unprefixed) Atom
   namespace, leaves entries that already have an <updated> untouched (so it is
   idempotent and never changes a valid feed), and is a no-op on documents with
   no <entry> (e.g. RSS2). *)
let repair_missing_updated (xml : string) : string =
  match Str.search_forward entry_open_re xml 0 with
  | exception Not_found -> xml
  | first_entry ->
      (* Feed-level <updated>, used as the fallback when an entry has neither
         <updated> nor <published>. Only count it if it precedes the first
         entry, so an entry's own <updated> is never mistaken for it. *)
      let feed_updated =
        match Str.search_forward updated_elt_re xml 0 with
        | exception Not_found -> None
        | mstart when mstart < first_entry -> Some (Str.matched_group 2 xml)
        | _ -> None
      in
      let buf = Buffer.create (String.length xml + 64) in
      let pos = ref 0 in
      let continue = ref true in
      while !continue do
        match Str.search_forward entry_open_re xml !pos with
        | exception Not_found ->
            Buffer.add_substring buf xml !pos (String.length xml - !pos);
            continue := false
        | estart -> (
            let open_end = Str.match_end () in
            match find_from xml "</entry>" open_end with
            | None ->
                Buffer.add_substring buf xml !pos (String.length xml - !pos);
                continue := false
            | Some cstart ->
                (* Text before this entry, then the entry's open tag, verbatim. *)
                Buffer.add_substring buf xml !pos (estart - !pos);
                Buffer.add_substring buf xml estart (open_end - estart);
                let inner = String.sub xml open_end (cstart - open_end) in
                let repaired =
                  if has_updated inner then inner
                  else
                    match fill_from_published inner with
                    | Some inner' -> inner'
                    | None -> (
                        match feed_updated with
                        | Some v -> "<updated>" ^ v ^ "</updated>" ^ inner
                        | None -> inner)
                in
                Buffer.add_string buf repaired;
                Buffer.add_string buf "</entry>";
                pos := cstart + String.length "</entry>")
      done;
      Buffer.contents buf

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
      (* Void-element repair first (makes the document well-formed XML), then
         fill any entry missing a mandatory <updated>. Each pass is a no-op on
         feeds that do not need it, so both classes recover in one retry. *)
      try parse (repair_missing_updated (sanitize_void_elements xml))
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
