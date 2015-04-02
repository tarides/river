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

(* Download urls and cache them — especially during development, it
   slows down the rendering to download over and over again the same
   URL. *)

open Printf
open Lwt
open Cohttp
open Cohttp_lwt_unix
open Cohttp.Response
open Cohttp.Header
open Cohttp.Code

let age fn =
  let now = Unix.time () in (* in sec *)
  let modif = (Unix.stat fn).Unix.st_mtime in
  now -. modif

let time_of_secs s =
  let s = truncate s in
  let m = s / 60 and s = s mod 60 in
  let h = m / 60 and m = m mod 60 in
  sprintf "%i:%02im%is" h m s

exception Status_unhandled of string

exception Timeout

let max_num_redirects = 5

let get_location headers =
  let (k,v) = List.find (fun (k,v) -> k = "location") @@ Header.to_list headers
  in v

let rec get_uri uri = function
  | 0 -> raise (Status_unhandled "Too many redirects")
  | n ->
      let main =
        Cohttp_lwt_unix.Client.get uri >>= fun (resp, body) ->
        match resp.status with
        | `OK -> Cohttp_lwt_body.to_string body
        | `Found | `See_other | `Moved_permanently ->
            (let l = Uri.of_string @@ get_location resp.headers in
            match Uri.host l with
            | Some _ -> get_uri l (n-1)
            | None ->
                let host = Uri.host uri in
                let scheme = Uri.scheme uri in
                let new_uri = Uri.with_scheme (Uri.with_host l host) scheme in
                get_uri new_uri (n-1))
        | _ -> raise @@ Status_unhandled (string_of_status resp.status)
      in
      let timeout = Lwt_unix.sleep (float_of_int 3) >>= fun () ->
                    Lwt.fail Timeout
      in
      Lwt.pick [main; timeout]


let cache_secs = 3600. (* 1h *)

let get ?(cache_secs=cache_secs) url =
  let md5 = Digest.to_hex(Digest.string url) in
  let fn = Filename.concat Filename.temp_dir_name ("ocamlorg-" ^ md5) in
  eprintf "Downloading %s ... %!" url;
  let get_from_cache () =
    let fh = open_in fn in
    let data = input_value fh in
    close_in fh;
    eprintf "done.\n  (using cache %s, updated %s ago).\n%!"
            fn (time_of_secs(age fn));
    data in
  if Sys.file_exists fn && age fn <= cache_secs then get_from_cache()
  else (
    try
      let data = Lwt_main.run @@ get_uri (Uri.of_string url) max_num_redirects in
      eprintf "done %!";
      let fh = open_out fn in
      output_value fh data;
      close_out fh;
      eprintf "(cached).\n%!";
      data
    with
    | (Status_unhandled s | Failure s) as e -> (eprintf "Failed: %s\n" s; raise e)
    | Timeout as e -> (eprintf "Failed: Timeout\n"; raise e)
  )
