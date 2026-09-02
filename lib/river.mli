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

type source = { name : string; url : string }
(** The source of a feed. *)

type feed
type post

val fetch :
  ?timeout:float -> ?user_agent:string -> ?repair:bool -> source -> feed
(** [fetch ?timeout ?user_agent ?repair source] returns an Atom or RSS feed
    from a source.

    @param timeout Connection timeout in seconds. Default: [3.].
    @param user_agent Value sent in the [User-Agent] HTTP header. Omitted by
      default.
    @param repair
      When [true], if the document fails to parse as-is, retry after two
      conservative fix-ups: self-closing HTML void elements (see
      {!sanitize_void_elements}) and defaulting any entry missing a mandatory
      [<updated>] (see {!repair_missing_updated}). Feeds that already parse are
      never modified. Default: [false]. *)

val of_string : ?repair:bool -> source -> string -> feed
(** [of_string ?repair source xml] parses the in-memory feed document [xml] as
    if it had been fetched from [source.url], performing no HTTP request. See
    {!fetch} for [repair]. *)

val sanitize_void_elements : string -> string
(** [sanitize_void_elements xml] rewrites HTML void elements ([<img>], [<br>],
    …) into self-closing form: both unclosed ([<img ...>]) and
    redundantly-closed ([<img ...></img>]) occurrences become [<img ... />].
    Already self-closed elements and escaped ([type="html"]) content are left
    untouched. This is the transform applied by {!fetch} and {!of_string} when
    [~repair:true]; it is exposed for testing and reuse. *)

val repair_missing_updated : string -> string
(** [repair_missing_updated xml] fills in a mandatory entry-level [<updated>]
    element wherever an Atom [<entry>] lacks one, defaulting it to (1) the
    entry's own [<published>] if present, else (2) the feed-level [<updated>].
    Entries that already have an [<updated>] and documents with no [<entry>]
    (e.g. RSS2) are left unchanged, so it is idempotent and never alters a valid
    feed. This is the second transform applied by {!fetch} and {!of_string} when
    [~repair:true]; it is exposed for testing and reuse. *)

val name : feed -> string
(** [name feed] is the name of the feed source passed to [fetch]. *)

val url : feed -> string
(** [url feed] is the url of the feed source passed to [fetch]. *)

val posts : feed list -> post list
(** [posts feeds] is the list of deduplicated posts of the given feeds. *)

val feed : post -> feed
(** [feed post] is the feed the post originates from. *)

val title : post -> string
(** [title post] is the title of the post. *)

val link : post -> Uri.t option
(** [link post] is the link of the post. *)

val date : post -> Syndic.Date.t option
(** [date post] is the date of the post. *)

val author : post -> string
(** [author post] is the author of the post. *)

val email : post -> string
(** [email post] is the email of the post. *)

val content : post -> string
(** [content post] is the content of the post. *)

val summary : post -> string option
(** [summary post] is the short description provided by the feed itself: the
    Atom [<summary>] or the RSS2 [<description>], as plain text. [None] when the
    feed provides no such element. *)

val meta_description :
  ?timeout:float -> ?user_agent:string -> post -> string option
(** [meta_description ?timeout ?user_agent post] is a short description of the
    post.

    When the feed provides one, [summary post] is returned directly. Otherwise
    we fetch the content of [link post] and look for an HTML meta tag with the
    name "description" or "og:description".

    @param timeout Connection timeout in seconds. Default: [3.].
    @param user_agent Value sent in the [User-Agent] HTTP header. Omitted by
      default. *)

val seo_image :
  ?timeout:float -> ?user_agent:string -> post -> string option
(** [seo_image ?timeout ?user_agent post] is the image to be used by social
    networks and links to the post.

    @param timeout Connection timeout in seconds. Default: [3.].
    @param user_agent Value sent in the [User-Agent] HTTP header. Omitted by
      default.

    To get the seo image, we make get the content of [link post] and look for an
    HTML meta tag with the name "og:image" or "twitter:image". *)

val create_atom_entries : post list -> Syndic.Atom.entry list
(** [create_atom_feed posts] creates a list of atom entries, which can then be
    used to create an atom feed that is an aggregate of the posts. *)
