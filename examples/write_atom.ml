open Planet
open Syndic.Atom

let main () =
  let in_file = "examples/data_blog.txt" in
  let out_file = "atom.xml" in
  let posts = get_posts in_file in
  let entries = mk_entries posts in
  let feed =
    let authors = [ author "OCaml Labs" ] in
    let id = "http://ocaml.io/blogs/atom.xml" in
    let links = [ link ~rel:Self @@ Uri.of_string id ] in
    let title : text_construct = Text "OCaml Labs: Real World Functional Programming" in
    let updated = CalendarLib.Calendar.now () in
    feed ~authors ~links ~id ~title ~updated entries in
  let out_channel = open_out out_file in
  output feed (`Channel out_channel);
  close_out out_channel

let () = main ()
