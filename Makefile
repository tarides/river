build:
	ocamlbuild -j 4 -use-ocamlfind -package syndic,lwt,cohttp.lwt,netstring -tag thread lib/planet.native

www: build
	./planet.native
	cd pages && env PATH=../ucampas:$$PATH ucampas -i -r3 blogs

clean:
	rm -rf _build *.native *.cmx *.cmi *.o *~
