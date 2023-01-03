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

type t = {
  title : string;
  link : Uri.t option;
  date : Syndic.Date.t option;
  feed : Feed.t;
  author : string;
  email : string;
  content : string;
  mutable link_response : (string, string) result option;
}

(* Do not trust sites using XML for HTML content. Convert to string and parse
   back. (Does not always fix bad HTML unfortunately.) *)
let html_of_syndic h =
  let ns_prefix _ = Some "" in
  (String.concat "" (List.map (Syndic.XML.to_string ~ns_prefix) h))

let string_of_option = function None -> "" | Some s -> s

let post_compare p1 p2 =
  (* Most recent posts first. Posts with no date are always last *)
  match (p1.date, p2.date) with
  | Some d1, Some d2 -> Syndic.Date.compare d2 d1
  | None, Some _ -> 1
  | Some _, None -> -1
  | None, None -> 1

let rec remove n l =
  if n <= 0 then l else match l with [] -> [] | _ :: tl -> remove (n - 1) tl

let rec take n = function
  | [] -> []
  | e :: tl -> if n > 0 then e :: take (n - 1) tl else []

(* Blog feed
 ***********************************************************************)

let post_of_atom ~(feed : Feed.t) (e : Syndic.Atom.entry) =
  let link =
    try
      Some
        (List.find (fun l -> l.Syndic.Atom.rel = Syndic.Atom.Alternate) e.links)
          .href
    with Not_found -> (
      match e.links with l :: _ -> Some l.href | [] -> None)
  in
  let date =
    match e.published with Some _ -> e.published | None -> Some e.updated
  in
  let content =
    match e.content with
    | Some (Text s) ->  s
    | Some (Html (_xmlbase, s)) ->   s
    | Some (Xhtml (_xmlbase, h)) -> html_of_syndic  h
    | Some (Mime _) | Some (Src _) | None -> (
        match e.summary with
        | Some (Text s) ->  s
        | Some (Html (_xmlbase, s)) ->   s
        | Some (Xhtml (_xmlbase, h)) -> html_of_syndic  h
        | None -> "")
  in
  let author, _ = e.authors in
  {
    title = Util.string_of_text_construct e.title;
    link;
    date;
    feed;
    author = author.name;
    email = "";
    content;
    link_response = None;
  }

let post_of_rss2 ~(feed : Feed.t) it =
  let title, content =
    match it.Syndic.Rss2.story with
    | All (t, _xmlbase, d) -> (
        ( t,
          match it.content with
          | _, "" -> d
          | _xmlbase, c -> c ))
    | Title t ->
        let _xmlbase, c = it.content in
        (t, c)
    | Description (_xmlbase, d) -> (
        ( "",
          match it.content with
          | _, "" -> d
          | _xmlbase, c -> c ))
  in
  let link =
    match (it.guid, it.link) with
    | Some u, _ when u.permalink -> Some u.data
    | _, Some _ -> it.link
    | Some u, _ ->
        (* Sometimes the guid is indicated with isPermaLink="false" but is
           nonetheless the only URL we get (e.g. ocamlpro). *)
        Some u.data
    | None, None -> None
  in
  {
    title;
    link;
    feed;
    author = feed.name;
    email = string_of_option it.author;
    content;
    date = it.pubDate;
    link_response = None;
  }

let posts_of_feed c =
  match c.Feed.content with
  | Feed.Atom f -> List.map (post_of_atom ~feed:c) f.Syndic.Atom.entries
  | Feed.Rss2 ch -> List.map (post_of_rss2 ~feed:c) ch.Syndic.Rss2.items

let mk_entry post =
  let content = Syndic.Atom.Html (None, post.content) in
  let contributors =
    [ Syndic.Atom.author ~uri:(Uri.of_string post.feed.url) post.feed.name ]
  in
  let links =
    match post.link with
    | Some l -> [ Syndic.Atom.link ~rel:Syndic.Atom.Alternate l ]
    | None -> []
  in
  (* TODO: include source *)
  let id =
    match post.link with
    | Some l -> l
    | None -> Uri.of_string (Digest.to_hex (Digest.string post.title))
  in
  let authors = (Syndic.Atom.author ~email:post.email post.author, []) in
  let title : Syndic.Atom.text_construct = Syndic.Atom.Text post.title in
  let updated =
    match post.date with
    (* Atom entry requires a date but RSS2 does not. So if a date
     * is not available, just capture the current date. *)
    | None -> Ptime.of_float_s (Unix.gettimeofday ()) |> Option.get
    | Some d -> d
  in
  Syndic.Atom.entry ~content ~contributors ~links ~id ~authors ~title ~updated
    ()

let mk_entries posts = List.map mk_entry posts

let get_posts ?n ?(ofs = 0) planet_feeds =
  let posts = List.concat @@ List.map posts_of_feed planet_feeds in
  let posts = List.sort post_compare posts in
  let posts = remove ofs posts in
  match n with None -> posts | Some n -> take n posts

(* Fetch the link response and cache it. *)
let fetch_link t =
  match (t.link, t.link_response) with
  | None, _ -> None
  | Some _, Some (Ok x) -> Some x
  | Some _, Some (Error _) -> None
  | Some link, None -> (
      try
        let response = Http.get (Uri.to_string link) in
        t.link_response <- Some (Ok response);
        Some response
      with _exn ->
        t.link_response <- Some (Error "");
        None)
