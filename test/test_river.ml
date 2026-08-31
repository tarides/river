(* White-box tests for River. The [River__Post] / [River__Feed] modules are the
   library's internal units (wrapped under [River]); we reference them directly
   so feeds can be built from fixture XML without any network access. *)

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else (
    incr failures;
    Printf.printf "FAIL - %s\n" name)

(* [River.post] is [River__Post.t], but sealed abstract in river.mli. This
   zero-cost coercion lets us feed internally-built posts to the public API
   offline (no network). *)
external to_post : River__Post.t -> River.post = "%identity"

let feed_of ~url xml =
  let xmlbase = Uri.of_string url in
  let content = River__Feed.classify_feed ~xmlbase xml in
  { River__Feed.name = "test"; title = "test"; url; content }

let one_post ~url xml =
  match River__Post.get_posts [ feed_of ~url xml ] with
  | [ p ] -> p
  | ps -> failwith (Printf.sprintf "expected 1 post, got %d" (List.length ps))

(* --- Issue #12: use the feed's <summary> / <description> ------------------- *)

let atom_with_summary =
  {xml|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test feed</title>
  <id>urn:uuid:feed-0000</id>
  <updated>2024-01-01T00:00:00Z</updated>
  <author><name>Test Author</name></author>
  <entry>
    <title>Atom post</title>
    <id>urn:uuid:aaaaaaaa-0000-0000-0000-000000000001</id>
    <updated>2024-01-03T00:00:00Z</updated>
    <link href="https://example.org/atom-post" rel="alternate"/>
    <summary>A concise Atom summary.</summary>
    <content type="html">full body here</content>
  </entry>
</feed>|xml}

let rss2_with_description =
  {xml|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test channel</title>
    <link>https://example.org/</link>
    <description>A channel</description>
    <item>
      <title>RSS post</title>
      <link>https://example.org/rss-post</link>
      <guid>https://example.org/rss-post</guid>
      <description>A concise RSS description.</description>
      <pubDate>Wed, 03 Jan 2024 00:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>|xml}

let rss2_without_description =
  {xml|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test channel</title>
    <link>https://example.org/</link>
    <description>A channel</description>
    <item>
      <title>Title-only RSS post</title>
      <link>https://example.org/title-only</link>
      <guid>https://example.org/title-only</guid>
      <pubDate>Wed, 03 Jan 2024 00:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>|xml}

let () =
  let p = one_post ~url:"https://example.org/atom" atom_with_summary in
  check "atom <summary> is exposed"
    (River.summary (to_post p) = Some "A concise Atom summary.");
  (* meta_description must return the feed summary without any network call. *)
  check "meta_description prefers the atom summary"
    (River.meta_description (to_post p) = Some "A concise Atom summary.")

let () =
  let p = one_post ~url:"https://example.org/rss" rss2_with_description in
  check "rss2 <description> is exposed"
    (River.summary (to_post p) = Some "A concise RSS description.");
  check "meta_description prefers the rss2 description"
    (River.meta_description (to_post p) = Some "A concise RSS description.")

let () =
  let p = one_post ~url:"https://example.org/rss" rss2_without_description in
  check "no summary when the feed provides none"
    (River.summary (to_post p) = None)

let () =
  if !failures > 0 then (
    Printf.printf "\n%d check(s) failed\n" !failures;
    exit 1)
  else print_string "\nAll checks passed\n"
