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

let get_location headers =
  let (k,v) = List.find (fun (k,v) -> k = "location") @@ Header.to_list headers
  in v

let rec get_url url =
  Cohttp_lwt_unix.Client.get @@ Uri.of_string url
  >>= fun (resp, body) ->
        match resp.status with
          | `OK -> Cohttp_lwt_body.to_string body
          | `Found | `See_other | `Moved_permanently -> get_url @@ get_location resp.headers
          | _ -> raise @@ Status_unhandled (string_of_status resp.status)

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
      let data = Lwt_main.run @@ get_url url in
      eprintf "done %!";
      let fh = open_out fn in
      output_value fh data;
      close_out fh;
      eprintf "(cached).\n%!";
      data
    with Status_unhandled s as e ->
      (eprintf "FAILED!: %s\n" s;
       raise e)
  )
