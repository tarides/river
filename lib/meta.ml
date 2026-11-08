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

(** This module determines an image to be used as preview of a website.

    It does this by following the same logic Google+ and other websites use, and
    described in this article:
    https://www.raymondcamden.com/2011/07/26/How-are-Facebook-and-Google-creating-link-previews *)

let og_image html =
  let open Soup in
  let soup = parse html in
  try soup $ "meta[property=og:image]" |> R.attribute "content" |> Option.some
  with Failure _ -> None

let image_src html =
  let open Soup in
  let soup = parse html in
  try soup $ "link[rel=\"image_src\"]" |> R.attribute "href" |> Option.some
  with Failure _ -> None

let twitter_image html =
  let open Soup in
  let soup = parse html in
  try
    soup $ "meta[name=\"twitter:image\"]" |> R.attribute "content"
    |> Option.some
  with Failure _ -> None

let og_description html =
  let open Soup in
  let soup = parse html in
  try
    soup $ "meta[property=og:description]" |> R.attribute "content"
    |> Option.some
  with Failure _ -> None

(* Non-blank [content] of the first [<meta>] whose [attr] attribute equals
   [value], compared ASCII case-insensitively as HTML specifies for [name]. *)
let meta_content ~attr ~value html =
  let open Soup in
  parse html $$ "meta" |> to_list
  |> List.find_map (fun el ->
         match (attribute attr el, attribute "content" el) with
         | Some a, Some c
           when String.lowercase_ascii a = value && String.trim c <> "" ->
             Some c
         | _ -> None)

(* The standard tag is [<meta name="description">]; [property="description"] is
   kept as a fallback for pages that misuse the Open Graph attribute. *)
let description_tag html =
  match meta_content ~attr:"name" ~value:"description" html with
  | Some _ as d -> d
  | None -> meta_content ~attr:"property" ~value:"description" html

let preview_image html =
  let preview_image =
    match og_image html with
    | None -> (
        match image_src html with
        | None -> twitter_image html
        | Some x -> Some x)
    | Some x -> Some x
  in
  match Option.map String.trim preview_image with
  | Some "" -> None
  | Some x -> Some x
  | None -> None

let description html =
  let candidates = [ og_description; description_tag ] in
  List.find_map
    (fun f ->
      match Option.map String.trim (f html) with
      | Some "" | None -> None
      | Some x -> Some x)
    candidates
