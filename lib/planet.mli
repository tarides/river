(*
 * Copyright (c) 2014, OCaml.org project
 * Copyright (c) 2015 KC Sivaramakrishnan <sk826@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*)


type html = Nethtml.document list


type feed =
    Atom of Syndic.Atom.feed
  | Rss2 of Syndic.Rss2.channel
  | Broken of string
(** The feed is either an Atom or Rss2. If the feed is Broken [message], then
    the [message] gives the reason. *)

type contributor = {
  name  : string;
  title : string;
  url   : string;
  feed  : feed;
}
(** Feed information. *)

type post = {
  title : string;
  link  : Uri.t option;
  date  : Syndic.Date.t option;
  contributor : contributor;
  author : string;
  email : string;
  desc  : html;
}
(** Each post has a title, author, email and content (desc). The link, if
    available, points to the url of the post. *)

val get_posts: ?n:int -> ?ofs:int -> string -> post list
(** [get_posts n ofs fname] fetches a deduplicated list of posts, sorted based
    on the date, with the lastest post appearing first. The optional argument [n]
    fetches the first [n] posts. By default, all the posts are fetched. [ofs]
    represents the offset into the post list. For example, [get_posts 10 10]
    fetches the posts 10 to 20.

    [fname] is the input file with the list of feeds. The format is:

      <feed_name>|<feed_url>
      <feed_name>|<feed_url>
      ...
  *)

val prefix_of_html: html -> int -> html
(** [prefix_of_html html n] truncates the given document to [n] characters.
    The truncated document is ensured to be a well-formed docuemnt. *)
