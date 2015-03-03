open Syndic
open Http
open Printf
open Data
open Data.FeedInfo

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
  face  : string option;
  face_height : int
}

let classify_feed ~xmlbase (xml: string) =
  try Atom(Atom.parse ~xmlbase (Xmlm.make_input (`String(0, xml))))
  with Atom.Error.Error _ ->
          try Rss2(Rss2.parse ~xmlbase (Xmlm.make_input (`String(0, xml))))
          with Rss2.Error.Error _ ->
                Broken "Neither Atom nor RSS2 feed"

let feed_of_info (feed_info:Data.FeedInfo.t) =
  try
    let xmlbase = Uri.of_string @@ feed_info.url in
    let feed = classify_feed ~xmlbase (Http.get feed_info.url) in
    let title = match feed with
      | Atom atom -> string_of_text_construct atom.Atom.title
      | Rss2 ch -> ch.Rss2.title
      | Broken _ -> "" in
    { name = feed_info.name; face = feed_info.face; title; feed;
      face_height = feed_info.face_height; url = feed_info.url}
  with
  | Status_unhandled s ->
      { name = feed_info.name; face = feed_info.face; title="";
        feed = Broken s; face_height = feed_info.face_height;
        url = feed_info.url }

