let sources =
  River.
    [
      { name = "KC Sivaramakrishnan"; url = "http://kcsrk.info/atom-ocaml.xml" };
      {
        name = "Amir Chaudhry";
        url = "http://amirchaudhry.com/tags/ocamllabs-atom.xml";
      };
    ]

let main () =
  let feeds = List.map River.fetch sources in
  let posts = River.posts feeds in
  let entries = River.create_atom_entries posts in
  let feed =
    let authors = [ Syndic.Atom.author "OCaml Blog" ] in
    let id = Uri.of_string "https://ocaml.org/atom.xml" in
    let links = [ Syndic.Atom.link ~rel:Self id ] in
    let title : Syndic.Atom.text_construct =
      Text "OCaml Blog: Read the latest OCaml news from the community."
    in
    let updated = Ptime.of_float_s (Unix.gettimeofday ()) |> Option.get in
    Syndic.Atom.feed ~authors ~links ~id ~title ~updated entries
  in
  let out_channel = open_out "example/atom.xml" in
  Syndic.Atom.output feed (`Channel out_channel);
  close_out out_channel

let () =
  Printexc.record_backtrace true;
  main ()
