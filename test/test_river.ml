(* White-box tests for River. The [River__Post] / [River__Feed] modules are the
   library's internal units (wrapped under [River]); we reference them directly
   so feeds can be built from fixture XML without any network access. *)

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else (
    incr failures;
    Printf.printf "FAIL - %s\n" name)

let feed_of_atom ~url xml =
  let xmlbase = Uri.of_string url in
  let content = River__Feed.classify_feed ~xmlbase xml in
  { River__Feed.name = "test"; title = "test"; url; content }

(* --- Issue #13: respect the source <id> and resolve relative links --------- *)

let atom_two_entries =
  {xml|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <id>urn:uuid:feed-0000</id>
  <updated>2024-01-01T00:00:00Z</updated>
  <author><name>Test Author</name></author>
  <entry>
    <title>Post One</title>
    <id>urn:uuid:aaaaaaaa-0000-0000-0000-000000000001</id>
    <updated>2024-01-03T00:00:00Z</updated>
    <link href="/Posts/One" rel="alternate"/>
    <content type="html">hello</content>
  </entry>
  <entry>
    <title>Post Two</title>
    <id>urn:uuid:bbbbbbbb-0000-0000-0000-000000000002</id>
    <updated>2024-01-02T00:00:00Z</updated>
    <link href="/Posts/Two" rel="alternate"/>
    <content type="html">world</content>
  </entry>
</feed>|xml}

let () =
  let feed = feed_of_atom ~url:"https://example.org/atom" atom_two_entries in
  let posts = River__Post.get_posts [ feed ] in
  check "two entries yield two posts" (List.length posts = 2);
  (* Most recent first: Post One (2024-01-03) before Post Two (2024-01-02). *)
  let first = List.hd posts in
  check "relative link resolved to absolute"
    (first.River__Post.link
    = Some (Uri.of_string "https://example.org/Posts/One"));
  check "source <id> preserved on the post"
    (first.River__Post.id
    = Some (Uri.of_string "urn:uuid:aaaaaaaa-0000-0000-0000-000000000001"));
  (* The generated Atom entry must carry the source urn:uuid, not the link. *)
  let entries = River__Post.mk_entries posts in
  let ids =
    List.map (fun (e : Syndic.Atom.entry) -> Uri.to_string e.id) entries
  in
  check "output entry keeps urn:uuid id (not the link)"
    (List.mem "urn:uuid:aaaaaaaa-0000-0000-0000-000000000001" ids);
  check "output entry id is not the link"
    (not (List.mem "https://example.org/Posts/One" ids))

(* --- Issue #13: deduplication (river.mli promises deduplicated posts) ------- *)

let atom_duplicated_id =
  {xml|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <id>urn:uuid:feed-0001</id>
  <updated>2024-01-01T00:00:00Z</updated>
  <author><name>Test Author</name></author>
  <entry>
    <title>Same post, first copy</title>
    <id>urn:uuid:dddddddd-0000-0000-0000-00000000000d</id>
    <updated>2024-01-05T00:00:00Z</updated>
    <link href="/Posts/Dup" rel="alternate"/>
    <content type="html">copy A</content>
  </entry>
  <entry>
    <title>Same post, second copy</title>
    <id>urn:uuid:dddddddd-0000-0000-0000-00000000000d</id>
    <updated>2024-01-04T00:00:00Z</updated>
    <link href="/Posts/Dup" rel="alternate"/>
    <content type="html">copy B</content>
  </entry>
</feed>|xml}

let () =
  let feed = feed_of_atom ~url:"https://example.org/atom" atom_duplicated_id in
  let posts = River__Post.get_posts [ feed ] in
  check "entries sharing an <id> are deduplicated" (List.length posts = 1)

let () =
  if !failures > 0 then (
    Printf.printf "\n%d check(s) failed\n" !failures;
    exit 1)
  else print_string "\nAll checks passed\n"
