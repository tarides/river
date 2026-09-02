(* Regression tests for [~repair] / [repair_missing_updated]: feeds that are
   well-formed XML but that Syndic rejects because an <entry> is missing the
   mandatory <updated> element (RFC 4287). *)

let source : River.source = { name = "test"; url = "https://example.org/feed.xml" }

let well_formed (xml : string) : bool =
  let i = Xmlm.make_input (`String (0, xml)) in
  try
    while not (Xmlm.eoi i) do
      ignore (Xmlm.input i)
    done;
    true
  with Xmlm.Error _ -> false

let date_is post s =
  match River.date post with
  | Some d -> Syndic.Date.compare d (Syndic.Date.of_rfc3339 s) = 0
  | None -> false

let post_titled posts title =
  List.find (fun p -> String.equal (River.title p) title) posts

(* Well-formed Atom, but the second entry has <published> and no <updated>. *)
let missing_updated =
  {|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <updated>2020-01-01T00:00:00Z</updated>
  <id>urn:example:feed</id>
  <author><name>Test Author</name></author>
  <entry>
    <title>Valid post</title>
    <updated>2021-01-01T00:00:00Z</updated>
    <id>urn:example:1</id>
    <link href="https://example.org/1"/>
    <content type="text">hello</content>
  </entry>
  <entry>
    <title>Modular Explicits in OCaml</title>
    <published>2024-05-10T00:00:00Z</published>
    <id>urn:example:2</id>
    <link href="https://example.org/2"/>
    <content type="text">world</content>
  </entry>
</feed>|}

(* Well-formed Atom whose only entry has neither <published> nor <updated>. *)
let no_entry_dates =
  {|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <updated>2020-06-15T12:00:00Z</updated>
  <id>urn:example:feed</id>
  <author><name>Test Author</name></author>
  <entry>
    <title>No dates</title>
    <id>urn:example:3</id>
    <link href="https://example.org/3"/>
    <content type="text">x</content>
  </entry>
</feed>|}

(* Both problems at once: a bare <img> (not well-formed) and a missing
   <updated>. Recovering it exercises the void + updated pipeline. *)
let void_and_missing_updated =
  {|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <updated>2020-01-01T00:00:00Z</updated>
  <id>urn:example:feed</id>
  <author><name>Test Author</name></author>
  <entry>
    <title>Both problems</title>
    <published>2023-03-03T00:00:00Z</published>
    <id>urn:example:4</id>
    <link href="https://example.org/4"/>
    <content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p><img src="a.png"></p></div></content>
  </entry>
</feed>|}

(* Fully valid Atom: must be left byte-for-byte untouched by the repair. *)
let well_formed_atom =
  {|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Clean</title>
  <updated>2020-01-01T00:00:00Z</updated>
  <id>urn:example:clean</id>
  <author><name>Test Author</name></author>
  <entry>
    <title>Only post</title>
    <updated>2020-01-01T00:00:00Z</updated>
    <id>urn:example:c1</id>
    <link href="https://example.org/c1"/>
    <content type="text">clean</content>
  </entry>
</feed>|}

let () =
  (* This class of feed is genuine, well-formed XML (unlike the void-element
     case), yet Syndic rejects it on the missing <updated>. *)
  assert (well_formed missing_updated);
  (match River.of_string source missing_updated with
  | exception Failure _ -> ()
  | _ -> failwith "expected missing-<updated> feed to fail without ~repair");

  (* With repair, every entry is recovered and the repaired one takes its date
     from its own <published>. *)
  let feed = River.of_string ~repair:true source missing_updated in
  let posts = River.posts [ feed ] in
  assert (List.length posts = 2);
  assert (date_is (post_titled posts "Modular Explicits in OCaml") "2024-05-10T00:00:00Z");

  (* An entry with neither date falls back to the feed-level <updated>. *)
  let feed = River.of_string ~repair:true source no_entry_dates in
  let posts = River.posts [ feed ] in
  assert (List.length posts = 1);
  assert (date_is (List.hd posts) "2020-06-15T12:00:00Z");

  (* Void-element and missing-<updated> repairs compose in a single retry. *)
  assert (not (well_formed void_and_missing_updated));
  let feed = River.of_string ~repair:true source void_and_missing_updated in
  let posts = River.posts [ feed ] in
  assert (List.length posts = 1);
  assert (date_is (List.hd posts) "2023-03-03T00:00:00Z");

  (* Idempotent, and a valid feed is left byte-for-byte unchanged. *)
  let once = River.repair_missing_updated missing_updated in
  assert (String.equal once (River.repair_missing_updated once));
  assert (
    String.equal well_formed_atom (River.repair_missing_updated well_formed_atom));
  let clean = River.of_string ~repair:true source well_formed_atom in
  assert (List.length (River.posts [ clean ]) = 1);

  print_endline "river repair (updated) tests passed"
