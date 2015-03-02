open Feeds
open Posts
open Bootstrap
open Printf

(* Main
 ***********************************************************************)

let planet_feeds = List.map feed_of_info Data.all_feeds
let _ = write_post ?n:(Some 50) ~file:"pages/blogs/index-b.html" planet_feeds
