open Feeds
open Printf

let _ = List.iter
          (fun {feed; _} -> printf "%s" (Feeds.string_of_feed feed))
          Feeds.planet_feeds
