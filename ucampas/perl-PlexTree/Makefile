# Makefile for building and installing the perl-PlexTree package
# Markus Kuhn -- http://www.cl.cam.ac.uk/~mgk25/

.SUFFIXES: .pm .3 .ps .pdf $(SUFFIXES)

.ps.pdf:
	distill < $< > $@

.3.ps:
	groff -man $< > $@

.pm.3:
	pod2man $< > $@

all: PlexTree.pdf

MODULES=PlexTree

refman.pdf: $(MODULES:%=%.ps)
	cat $+ | distill > $@

distribution: README Makefile refman.pdf $(MODULES:%=%.pm) $(MODULES:%=%.3)
	tar cvzf \
	$(HOME)/public_html/download/perl-PlexTree-`date +%Y%m%d`.tar.gz $+

test:
	PERLDB_OPTS=NonStop=1 perl -w -d tests

INSTALLDIR=/anfs/www/tools/share/perl

install:
	mkdir -p $(INSTALLDIR)/PlexTree
	cp PlexTree.pm $(INSTALLDIR)/
	cp PlexTree/SGML.pm PlexTree/Text.pm $(INSTALLDIR)/PlexTree/

clean:
	rm -f *~ *.3 *.ps *.pdf
