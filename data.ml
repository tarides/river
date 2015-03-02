module FeedInfo = struct
  type t = {
    name : string;
    face : string;
    url : string;
    face_height : int;
  }

  let mk_feed ~name ?(face="mugshot/default.jpg") ?(face_height=50) url =
    { name; face; url; face_height}
end

open FeedInfo

let srg_syslog =
  mk_feed ~name:"SRG Syslog"
          "http://www.syslog.cl.cam.ac.uk/tag/ocamllabs/feed/atom"

let anil =
  mk_feed ~name:"Anil Madhavapeddy"
          ~face:"mugshots/avsm.jpg"
          "http://anil.recoil.org/feeds/atom-ocaml.xml"

let amir =
  mk_feed ~name:"Amir Chaudhry"
          ~face:"mugshots/amir.jpg"
          "http://amirchaudhry.com/tags/ocaml-labs-atom.xml"

let all_feeds = [ srg_syslog; anil; amir ]
