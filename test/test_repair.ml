(* Regression tests for [~repair] / [sanitize_void_elements]: feeds that are
   valid Atom apart from HTML void elements that are not self-closed. *)

let source : River.source = { name = "test"; url = "https://example.org/feed.xml" }

let well_formed (xml : string) : bool =
  let i = Xmlm.make_input (`String (0, xml)) in
  try
    while not (Xmlm.eoi i) do
      ignore (Xmlm.input i)
    done;
    true
  with Xmlm.Error _ -> false

(* An Atom feed whose xhtml content mixes the three <img> shapes:
   bare (unclosed), redundantly closed, and already self-closed. Only the
   first two break strict XML parsing. *)
let malformed_atom =
  {|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <updated>2020-01-01T00:00:00Z</updated>
  <id>urn:example:feed</id>
  <author><name>Test Author</name></author>
  <entry>
    <title>Post one</title>
    <updated>2020-01-01T00:00:00Z</updated>
    <id>urn:example:1</id>
    <link href="https://example.org/1"/>
    <content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p><img src="a.png" alt="bare"><br><img src="b.png" alt="paired"></img><img src="c.png" alt="ok" /></p></div></content>
  </entry>
</feed>|}

let () =
  (* The raw feed is not well-formed XML. *)
  assert (not (well_formed malformed_atom));

  (* Sanitizing makes it well-formed... *)
  let repaired = River.sanitize_void_elements malformed_atom in
  assert (well_formed repaired);

  (* ...and idempotent: a second pass changes nothing. *)
  assert (String.equal repaired (River.sanitize_void_elements repaired));

  (* Without repair, parsing fails exactly as before. *)
  (match River.of_string source malformed_atom with
  | exception Failure _ -> ()
  | _ -> failwith "expected malformed feed to fail without ~repair");

  (* With repair, the feed parses and its post is recovered. *)
  let feed = River.of_string ~repair:true source malformed_atom in
  let posts = River.posts [ feed ] in
  assert (List.length posts = 1);
  assert (String.equal (River.title (List.hd posts)) "Post one");

  (* A well-formed feed parses with or without repair and is left untouched by
     the sanitizer. *)
  let well_formed_atom =
    String.concat ""
      [
        {|<?xml version="1.0" encoding="UTF-8"?>|};
        {|<feed xmlns="http://www.w3.org/2005/Atom">|};
        {|<title>Clean</title><updated>2020-01-01T00:00:00Z</updated>|};
        {|<id>urn:example:clean</id>|};
        {|<author><name>Test Author</name></author>|};
        {|<entry><title>Only post</title>|};
        {|<updated>2020-01-01T00:00:00Z</updated><id>urn:example:c1</id>|};
        {|<link href="https://example.org/c1"/></entry></feed>|};
      ]
  in
  assert (
    String.equal well_formed_atom (River.sanitize_void_elements well_formed_atom));
  let clean = River.of_string ~repair:true source well_formed_atom in
  assert (List.length (River.posts [ clean ]) = 1);

  print_endline "river repair tests passed"
