all:
	ocamlbuild -j 4 -use-ocamlfind -package syndic,lwt,cohttp.lwt -tag thread lib/test.native

clean:
	rm -rf _build *.native *.cmx *.cmi *.o *~
