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

open River
open Syndic.Atom

let main () =
  let in_file = "examples/data_blog.txt" in
  let out_file = "atom.xml" in
  let posts = get_posts in_file in
  let entries = mk_entries posts in
  let feed =
    let authors = [ author "OCaml Labs" ] in
    let id = Uri.of_string "http://ocaml.io/blogs/atom.xml" in
    let links = [ link ~rel:Self id ] in
    let title : text_construct = Text "OCaml Labs: Real World Functional Programming" in
    let updated = Ptime_clock.now () in
    feed ~authors ~links ~id ~title ~updated entries in
  let out_channel = open_out out_file in
  output feed (`Channel out_channel);
  close_out out_channel

let () = main ()
