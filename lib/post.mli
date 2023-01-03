type t = {
  title : string;
  link : Uri.t option;
  date : Ptime.t option;
  feed : Feed.t;
  author : string;
  email : string;
  content : string;
  mutable link_response : (string, string) result option;
}

val mk_entries : t list -> Syndic.Atom.entry list
val get_posts : ?n:int -> ?ofs:int -> Feed.t list -> t list
val fetch_link : t -> string option
