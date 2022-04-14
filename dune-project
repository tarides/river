(lang dune 3.0)

(name river)

(documentation "https://kayceesrk.github.io/river/")

(source
 (github kayceesrk/river))

(license MIT)

(authors "KC Sivaramakrishnan <sk826@cl.cam.ac.uk>")

(maintainers "KC Sivaramakrishnan <sk826@cl.cam.ac.uk>")

(generate_opam_files true)

(package
 (name river)
 (synopsis "RSS2 and Atom feed aggregator for OCaml")
 (description "RSS2 and Atom feed aggregator for OCaml")
 (depends
  (ocaml
   (>= 4.08.0))
  dune
  (syndic
   (>= 1.5))
  (cohttp
   (>= 5.0.0))
  (cohttp-lwt
   (>= 5.0.0))
  (cohttp-lwt-unix
   (>= 5.0.0))
  ptime
  lwt
  ocamlnet
  lambdasoup
  (odoc :with-doc)))
