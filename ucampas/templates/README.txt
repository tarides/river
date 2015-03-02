
Ucampas house-style template files
----------------------------------

The "style" attribute of a node in the ucampas navigation tree
identifies which house-style template shall be applied to a page.

Each style template is a HTML file with embedded <?perl ... ?>
processing instructions. These Perl code snippets are executed after
the navigation tree has been built and the SGML parser has already
converted both the *-b.html source document as well as the style
template HTML file into a PlexTree parse tree.

The PlexTree and NavTree API used is (unfortunately still very
incompletely!) documented at

  perldoc perl-PlexTree/PlexTree.pm
  perldoc NavTree.pm

The Perl code snippets in the templates have access to several variables:

  $src   the (cursor to the root of the) HTML parse tree of the
         *-b.html source file

  $out   the (cursor to the root of the) HTML parse tree of the
         template file (and eventual output file)

  $c     a cursor to the node that represents the <?perl ... ?>
         processing instruction in the HTML parse tree of the template
         ($c->top is $out)

  $cur   a curser to the node in the navigation tree that represents
         the current web page

They can, for example, insert new text or elements using $c->insert(...)
right before the location of the respective <?perl ... ?> processing
instruction. After the execution of each such <?perl ... ?> processing
instruction, ucampas will automatically remove it from $out (i.e.
there is an implicit call to $c->cut at the end of each).

In particular, one of the processing instructions has to copy the body
of the web page from $src into $out, but they also may add navigation
menus, breadcrumbs, page titles and other features, based on the
structure and parameters found via $cur in the navigation tree.
Ucampas provides some subroutines to do much of the work (e.g.,
ucampas_head() to fill the <head> element with content, navbar() to
build a navigation menu, etc.).

After all the <?perl ... ?> processing instructions found in a
template have been executed, ucampas will also go over any <div
class="ucampas-..."> elements that it finds in $out, and finally will
serialize $out back into the output XHTML file.

Unfortunately, there exists no detailed documentation yet for writing
new housestyle templates, and the existing PlexTree API is likely to
be extended in future (and hopefully become much simpler). Therefore,
at the moment, best contact the author of ucampas if you want to write
a new housestyle.

The provided *.html example housestyles in this directory are those
actually used by the Computer Laboratory (also suitable for other
University of Cambridge departments) and Wolfson College, Cambridge.
See the associated *.txt files for more information.
