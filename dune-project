(lang dune 2.0)

(name river)

(documentation "https://tmattio.github.io/river/")

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
  (hyper
   (= 1.0.0~alpha1))
  ptime
  lwt
  ocamlnet
  (odoc :with-doc)))
