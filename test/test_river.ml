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

(* --- Issue #13: respect the source <id> and resolve relative links
   --------- *)

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
  let feed = feed_of ~url:"https://example.org/atom" atom_two_entries in
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

(* --- Issue #13: deduplication (river.mli promises deduplicated posts)
   ------- *)

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
  let feed = feed_of ~url:"https://example.org/atom" atom_duplicated_id in
  let posts = River__Post.get_posts [ feed ] in
  check "entries sharing an <id> are deduplicated" (List.length posts = 1)

(* --- Issue #12: use the feed's <summary> / <description>
   ------------------- *)

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

(* Has <content:encoded>, so <description> is a genuine summary (#22). *)
let rss2_with_description =
  {xml|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Test channel</title>
    <link>https://example.org/</link>
    <description>A channel</description>
    <item>
      <title>RSS post</title>
      <link>https://example.org/rss-post</link>
      <guid>https://example.org/rss-post</guid>
      <description>A concise RSS description.</description>
      <content:encoded><![CDATA[<p>The full article body.</p>]]></content:encoded>
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

(* --- Issue #22: word breaks, <meta name="description">, RSS2 summary ------ *)

let rss2_description_only =
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
      <description>&lt;p&gt;The whole article, in the description.&lt;/p&gt;</description>
      <pubDate>Wed, 03 Jan 2024 00:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>|xml}

let () =
  let p = one_post ~url:"https://example.org/rss" rss2_description_only in
  check "rss2 <description> used as content is not a summary"
    (River.summary (to_post p) = None);
  check "rss2 <description> still used as content"
    (River.content (to_post p) <> "")

let () =
  let pt = River__Post.plain_text_of_html in
  check "list items are separated"
    (pt
       {|<ul><li><a href="https://a.example/">tinybox: 150 classic games</a></li><li><a href="https://b.example/">IX, a full OS</a></li></ul>|}
    = Some "tinybox: 150 classic games IX, a full OS");
  check "paragraphs are separated" (pt "<p>a</p><p>b</p>" = Some "a b");
  check "line breaks separate words" (pt "a<br>b" = Some "a b");
  check "inline markup does not split words"
    (pt "foo<em>bar</em>" = Some "foobar");
  check "whitespace is collapsed"
    (pt "  one\n\n  two\tthree  " = Some "one two three");
  check "plain text is unchanged" (pt "Just text." = Some "Just text.");
  check "empty html gives None" (pt "<p> </p>" = None)

let () =
  let d = River__Meta.description in
  check "meta name=description is found"
    (d {|<html><head><meta name="description" content="Plain."></head></html>|}
    = Some "Plain.");
  check "meta property=description is a fallback"
    (d
       {|<html><head><meta property="description" content="Prop."></head></html>|}
    = Some "Prop.");
  check "og:description takes precedence"
    (d
       {|<html><head><meta name="description" content="Plain."><meta property="og:description" content="OG."></head></html>|}
    = Some "OG.");
  check "name=description without content falls back to property"
    (d
       {|<html><head><meta name="description"><meta property="description" content="Prop."></head></html>|}
    = Some "Prop.");
  check "no description meta gives None"
    (d {|<html><head><title>t</title></head></html>|} = None)

let () =
  let pt = River__Post.plain_text_of_html in
  check "nbsp-only html gives None" (pt "<p>&nbsp;</p>" = None);
  check "nbsp is collapsed and trimmed"
    (pt "<p>&nbsp;a&nbsp;&nbsp;b&nbsp;</p>" = Some "a b");
  check "form feed is whitespace" (pt "a\012b" = Some "a b");
  check "scripts and styles are dropped"
    (pt "<p>a</p><script>var x=1;</script><style>p{}</style><p>b</p>"
    = Some "a b");
  check "details/summary are separated"
    (pt "<details><summary>s</summary>body</details>" = Some "s body")

let () =
  let d = River__Meta.description in
  check "empty name=description falls back to property"
    (d
       {|<html><head><meta name="description" content=""><meta property="description" content="Prop."></head></html>|}
    = Some "Prop.");
  check "empty og:description falls back to name=description"
    (d
       {|<html><head><meta property="og:description" content=" "><meta name="description" content="Plain."></head></html>|}
    = Some "Plain.");
  check "meta name is matched case-insensitively"
    (d {|<html><head><meta name="Description" content="Cap."></head></html>|}
    = Some "Cap.")

let atom_summary ~typ body =
  Printf.sprintf
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
    <summary type="%s">%s</summary>
    <content type="html">full body here</content>
  </entry>
</feed>|xml}
    typ body

let () =
  let summary xml =
    River.summary (to_post (one_post ~url:"https://example.org/atom" xml))
  in
  check "atom html summary list items are separated"
    (summary
       (atom_summary ~typ:"html"
          "&lt;ul&gt;&lt;li&gt;one&lt;/li&gt;&lt;li&gt;two&lt;/li&gt;&lt;/ul&gt;")
    = Some "one two");
  check "atom xhtml summary list items are separated"
    (summary
       (atom_summary ~typ:"xhtml"
          {|<div xmlns="http://www.w3.org/1999/xhtml"><ul><li>one</li><li>two</li></ul></div>|})
    = Some "one two")

let rss2_item ~description ~encoded =
  Printf.sprintf
    {xml|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Test channel</title>
    <link>https://example.org/</link>
    <description>A channel</description>
    <item>
      <title>RSS post</title>
      <link>https://example.org/rss-post</link>
      <guid>https://example.org/rss-post</guid>
      <description>%s</description>
      <content:encoded>%s</content:encoded>
      <pubDate>Wed, 03 Jan 2024 00:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>|xml}
    description encoded

let () =
  let post d e =
    to_post
      (one_post ~url:"https://example.org/rss"
         (rss2_item ~description:d ~encoded:e))
  in
  check "rss2 description list items are separated"
    (River.summary
       (post
          "&lt;ul&gt;&lt;li&gt;one&lt;/li&gt;&lt;li&gt;two&lt;/li&gt;&lt;/ul&gt;"
          "&lt;p&gt;Body.&lt;/p&gt;")
    = Some "one two");
  let p = post "The description." "   " in
  check "whitespace-only content:encoded: no summary" (River.summary p = None);
  check "whitespace-only content:encoded: description is the content"
    (String.trim (River.content p) <> "")

(* An RSS2 description-only post has no summary, so [meta_description] reads the
   page's meta tags. Pre-seed the cached page to stay offline. *)
let () =
  let p = one_post ~url:"https://example.org/rss" rss2_description_only in
  p.River__Post.link_response <-
    Some
      (Ok
         {|<html><head><meta name="description" content="From the page."></head></html>|});
  check "meta_description falls back to the page for description-only rss2"
    (River.meta_description (to_post p) = Some "From the page.")

let () =
  if !failures > 0 then (
    Printf.printf "\n%d check(s) failed\n" !failures;
    exit 1)
  else print_string "\nAll checks passed\n"
