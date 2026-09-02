# unreleased

- Add an opt-in `?repair` flag to `River.fetch` (and a new `River.of_string`)
  that recovers feeds which are valid Atom/RSS apart from unclosed HTML void
  elements (e.g. `<img>`) in `type="xhtml"` content, by self-closing them
  before parsing. Off by default, so well-formed feeds are never modified.
  Also exposes `River.sanitize_void_elements`.
- Extend `?repair` to also recover well-formed Atom feeds that Syndic rejects
  because an `<entry>` is missing the mandatory `<updated>` element: it is
  defaulted to the entry's `<published>`, else the feed-level `<updated>`
  (#20). Also exposes `River.repair_missing_updated`.
- Respect the feed's own entry identity (Atom `<id>`, RSS2 guid) when
  generating Atom entries, resolve relative entry links to absolute URLs, and
  deduplicate merged posts (#13)
- Use the feed's own `<summary>` (Atom) / `<description>` (RSS2) when
  available: add a `summary` accessor and make `meta_description` prefer it
  over scraping the origin HTML page (#12)

# 0.5 - 2026-08-25

- Expose timeout and user-agent in the public API (#16)
- Remove unused ocamlnet dependency

# 0.4 - 2024-11-08

- Replace ocamlnet HTML parser with Lambda Soup (#15, @aantron)

# 0.3 - 2023-11-21

- Fall back to entry id if entry links doesn't exist (#11, @sabine)

# 0.2 - 2022-04-14

- Build with dune.
- Make the types abstract and add accessor functions.
- Support fetching meta description and SEO image from the posts links.

# 0.1.3 - 2015-07-28

- Make river compatible with the latest syndic API

# 0.1.2 - 2015-03-24

- Refactoring modules.

# 0.1.1 - 2015-03-19

- Upgrading version number.

# 0.1 - 2015-03-15

- Initial release
