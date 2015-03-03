module FeedInfo = struct
  type t = {
    name : string;
    face : string option;
    url : string;
    face_height : int;
  }

  let mk_feed ~name ?(face=None) ?(face_height=50) url =
    { name; face; url; face_height}
end

open FeedInfo

let srg_syslog =
  mk_feed ~name:"SRG Syslog"
          "http://www.syslog.cl.cam.ac.uk/tag/ocamllabs/feed/atom"

let anil =
  mk_feed ~name:"Anil Madhavapeddy"
          ~face:(Some "../mugshots/avsm.jpg")
          ~face_height:70
          "http://anil.recoil.org/feeds/atom-ocaml.xml"

let amir =
  mk_feed ~name:"Amir Chaudhry"
          ~face:(Some "../mugshots/amir.jpg")
          "http://amirchaudhry.com/tags/ocaml-labs-atom.xml"

let comp =
  mk_feed ~name:"Compiler Hacking"
          ~face:(Some "../images/hax0ring.jpg")
          "http://ocamllabs.github.io/compiler-hacking/rss.xml"

let monthly_news =
  mk_feed ~name:"OCL Monthly News"
          "http://www.cl.cam.ac.uk/projects/ocamllabs/news/atom.xml"

let heidi =
  mk_feed ~name:"Heidi Howard"
          ~face:(Some "../mugshots/heidi.jpg")
          "http://hh360.user.srcf.net/blog/category/pl/ocaml/feed/"

let mirage_os =
  mk_feed ~name:"Mirage OS"
          "http://openmirage.org/blog/atom.xml"

let tleonard =
  mk_feed ~name:"Thomas Leonard"
          ~face:(Some "../mugshots/tleonard.jpg")
          ~face_height:70
          "http://roscidus.com/blog/atom.xml"

let all_feeds = [ srg_syslog; anil; amir ; comp; monthly_news; heidi; mirage_os
                  ; tleonard ]
