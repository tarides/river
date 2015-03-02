all:
	ocamlbuild -j 4 -use-ocamlfind -package cow,cow.syntax,syndic,lwt,cohttp.lwt -tag thread -syntax camlp4o lib/test.native

clean:
	rm -rf _build *.native *.cmx *.cmi *.o *~
