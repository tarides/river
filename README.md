# River

[![Actions Status](https://github.com/tarides/river/workflows/CI/badge.svg)](https://github.com/tarides/river/actions)

RSS2 and Atom feed aggregator for OCaml


## Features

- Performs deduplication.
- Supports pagination and generating well-formed html prefix snippets.
- Support for generating aggregate feeds.
- Sorts the posts from most recent to oldest.
- Depends on Lambda Soup for html parsing.

## Installation

```bash
opam install river
```

## Usage

Here's an example program that aggregates the feeds from different sources:

```ocaml
let sources =
  River.
    [
      { name = "KC Sivaramakrishnan"; url = "http://kcsrk.info/atom-ocaml.xml" };
      {
        name = "Amir Chaudhry";
        url = "http://amirchaudhry.com/tags/ocamllabs-atom.xml";
      };
    ]

let () =
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
```

## Contributing

Take a look at our [Contributing Guide](CONTRIBUTING.md).