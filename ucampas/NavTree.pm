=head1 NAME

NavTree - the navigation tree data structure used by ucampas

=head1 SYNOPSIS

  use NavTree;

  NavTree::set_global_uconfig($global_uconfig);
  $cur = NavTree::find_file($filename);
  print $cur->top->print() . "\n";

=head1 WARNING

B<This documentation is far from ready, please come back later.>

=head1 SUMMARY

The NavTree package is an auxiliary library for the ucampas web page
formatting tool. It manages an in-memory tree data structure (a forest
of trees called NavTrees) in which each tree node represents a HTML
web page. Each NavTree also stores configuration parameters that can
be used to influence the processing of individual nodes (web pages) or
entire subtrees.

A NavTree is built from the content of uconfig.txt files that are
located in the same directories as the HTML pages.

The uconfig.txt configuration files serve two purposes. Firstly, they
define the presentation order of subpages located within a directory.
This is needed because the content of a normal Unix filesystem
directory is just a set of files that has no specified order (they are
usually just displayed alphabetically). Using uconfig.txt files, the
designer of a website navigation hierarchy can determine which
subdirectories or files in a directory represent the first, second,
etc. subpage of the page associated with this directory. Secondly,
uconfig.txt files can also be used to associate key=value parameter
pairs with each webpage.

Each node of a NavTree corresponds to a web page, and an associated
file or directory. Nodes corresponding to directories also represent
the index.html (or index.php, etc.) file contained in that directory.
The overall NavTree represents the hierarchical navigation structure
of a website, where each subnode represents a sub page. The structure
of the NavTree and the filesystem tree from which it was built are
normally the same, but some deviations are possible. For example, the
filesystem tree can be flatter than the corresponding navigation tree,
if "nosub" parameters are used to match NavTree subnodes with
file-system siblings, in the interest of shorter URLs. Also, symbolic
links can be used to build a single NavTree from several filesystem
trees.

NavTree is a subclass of the PlexTree package, therefore all the
PlexTree navigation and editing functions for PlexTrees also apply to
NavTrees. A NavTree is an in-memory PlexTree with additional methods
that are specific to ucampas navigation trees. The uconfig.txt files
use the normal textual PlexTree representation. Parameters can be
queried with the I<get> and I<param> methods, where the latter causes
parameters to be inherited across entire subtrees. Subpages are
list-nodes children of the node representing a web page, while the
directory of each node stores parameters. The text string associated
with each node contains its filename (which in case of a directory
ends with a slash). These filenames are those seen by the web browser,
that is where a bare-bones file text-b.html is used to automatically
generate a decorated file text.html, the latter will be listed in
uconfig.txt and in the NavTree. Where a webpage is a directory (with
index.html or index.php for the actual page content), only the
directory name is listed in uconfig.txt and the NavTree (the trailing
slash will be added automatically).

A NavTree is built lazily by calling the I<NavTree::find_file>
function on any file or directory name of interest. This function
starts with a given filesystem path and scans its successive parent
directories for as far as it can find uconfig.txt files in order to
identify the root of the relevant NavTree. Two files for which this
parent-directory scan does not lead to the same top-level uconfig.txt
file are part of separate NavTrees.

=head1 FUNCTIONS

=over 4

=cut

package NavTree;

use strict;
use PlexTree;          # underlying general-purpose "compound" data structure
use PlexTree::Text;    # PlexTree filter for text representation of compounds
use PlexTree::SGML;    # PlexTree filter for converting to/from HTML/XML
use Cwd 'abs_path';    # routines for determining current working directory
our @ISA = ("PlexTreeMem");

# recognized filenames for directory page content
my @index_fn = ('index.html', 'index.htm', 'index.php');
my @indexb_fn = ('index-b.html', 'index-b.htm', 'index-b.php');

# mapping from absolute pathnames to corresponding NavTree cursors
my %path2node;

# paths overridden via uorigin symlinks
my %overridepath;

# set of NavTree node-ids representing directories from which a
# uconfig.txt files has already been read
my %uconfig_done;

# override cl(); this implementation differs in three ways from the original:
#  * on-demand reading of further uconfig.txt files
#  * switch from NavTree to PlexTreeMem class if the current node no
#    longer represents a web page
#  * no support for substitution filters (not used in a NavTree)
sub cl {
    my ($self, @pos) = @_;

    while (@pos) {

	if ($self->tag == META()) {
	    # from here on we are no longer a NavTree node
	    return bless([ @$self ] => 'PlexTreeMem')->cl(@pos);
  	}
	
	my $pos = shift @pos;

        $self = $self->cl_r($pos);
        return undef unless defined $self;

	# do we still have to read a uconfig.txt file here?
	if (!$uconfig_done{$self->nid} && $self->tag == TEXT()
	    && $self->str =~ /\/\z/) {
	    #print "cl(".$self->dpath.") -> add_uconfig\n";
	    $self->add_uconfig;
	}

    }

    return $self;
}

# override cd(); this implementation differs from the original:
#  * switch from NavTree to PlexTreeMem class, as the current node no
#    longer represents a web page
sub cd {
    my ($self, @keys) = @_;
    my $d = bless [ @$self ] => 'PlexTreeMem';
    return $d->cd(@keys);
}


# Read in a uconfig.txt configuration file and return a PlexTreeMem
# cursor to it.
sub read_uconfig {
    my ($fn) = @_;
    my $f;
    return undef unless -e $fn;
    open($f, '<', $fn) or die("Cannot read configuration file '$fn': $!\n");

    # read uconfig.txt in compound text format
    local $/; # enable "slurp" mode
    my $t = <$f>;
    close $f;
    my $uconfig;
    if (!defined eval {
	$uconfig = c("($t )");
	}) {
	die(PlexTree::print_error($@, $fn));
    }
    close $f;
    return $uconfig;
}

# Read in the configuration files ${path}uconfig[2].txt and add them
# to the NavTree at the current position.
sub add_uconfig {
    my ($nav, $path) = @_;

    return if !defined $nav;
    return if $uconfig_done{$nav->nid}; # been here before?
    add_uconfig($nav->parent); # make sure we got the ancestors first
    $uconfig_done{$nav->nid} = 1;  # don't do this one again later
    return if $nav->tag == TEXT && $nav->str !~ /\/\z/; # this is no directory
    $path = $nav->fpath unless defined $path;
    #print "add_uconfig($path)\n";
    for my $fn ("${path}uconfig.txt", "${path}uconfig2.txt") {
	my $uconfig = read_uconfig($fn);
	return unless defined $uconfig;
        # merge the newly read subtree into the main NavTree
	my $skip = $nav->listlen; # nodes that need not be prepared again
	$nav->movedir($uconfig);
	foreach my $l ($uconfig->list_r) {
	    $nav->append->move($l)
	}
	# deal recursively with *glob expansion, fpath, path2node, etc.
	$nav->prepare_nodes($fn, $skip);
    }
}

# This is an auxiliary function for add_uconfig() that recursively processes
# the list nodes in uconfig.txt files that have just been parsed.
# Do not call it directly.
#
# Its performs *glob expansion, verifies filenames, sets fpath
# attributes where necessary, and adds each node to path2node.
# (Ideally, such processing should happen in a callback of c(),
#  such that error messages can refer to a line number. But such
#  call-backs remain not practical when keys are in c() discovered
#  to be keys only once they have been fully parsed. :-( )
sub prepare_nodes {
    my ($cur, $fn, $skip) = @_;

    my @nodes = $cur->list_r;
    splice @nodes, 0, $skip if $skip;
    return unless @nodes;

    my $directory = $cur->fsubdirname;

    # expand *glob list entries
    foreach my $c (@nodes) {
	if ($c->tag eq META()) {
	    if ($c->str =~ /^globr?$/) {
		# Use *glob('*-b.html') or *glob('*/') to
		# implicitely list all these files or
		# directories that exist but have not yet
		# been listed otherwise. Additional attributes
		# (as in "*glob('*-b.html', invisible=1)")
		# will be applied to all files found. The first
		# '/' and anything following in a match will be
		# discarded. Use *globr if you want reverse sorting
                # order.
		my $glob = $c->getl(0);
		unless ($glob) {
		    warn('$fn: ' . $c->apath('dir') .
			 '*' . $c->str . '() lacks argument');
		    $c->cut;
		    next;
		}
		my @list = glob($directory . $glob);
		@list = reverse @list if ($c->str eq 'globr');
		# remove $directory prefix from @list elements
		@list = grep {
		    index($_, $directory) == 0 ?
			(substr($_, 0, length($directory)) = '', 1) :
			0
		} @list;
		# remove any '/' and anything following, such that e.g.
		# *glob('*/index-b.html') can be used to get all directories
		# that contain an index-b.html file
		@list = grep { s/\/.*$//; 1 } @list;
		# convert *-b.html into *.html
		@list = grep { s/^(.+)-b(\.(?:html?|php))$/$1$2/i; 1 } @list;
		foreach my $match (@list) {
		    # check whether we had that one already
		    # (could surely be done more efficiently)
		    next if grep { $_->str eq $match } $c->list_r;
		    # add it, including any specified attributes
		    $c->insert->move(text($match)->copyfrom_dir($c));
		}
		$c->cut;
	    }
	}
    }

    @nodes = $cur->list_r;
    splice @nodes, 0, $skip if $skip;

    foreach my $c (@nodes) {
	next unless $c->tag == TEXT();
	my $filename = $c->str;

	# verify/fix filenames
	if ($filename =~ /\/.+$/) {
	    warn("$fn: no '/' permitted in filename '$filename' (ignored)\n");
	    $c->cut;
	    next;
	}
	if ($filename eq '.' || $filename eq '..') {
	    warn("$fn: filename '" . $c->apath . "' not permitted (ignored)\n");
	    $c->cut;
	    next;
	}
	my $path = abs_path($directory . $filename);
	$path .= '/' if -d $path;

	# check for override path via uorigin symlinks
	if (defined $overridepath{$path}) {
	    $path = $overridepath{$path};
	    # As a uorigin symlink implies that we are the root of a
	    # (usually non-public) off-URL-tree working subtree, we
	    # set url=file://..., just to ensure that the url() method
	    # will not return relative URLs for parent nodes. Users
	    # can still override this url value from uconfig2 if the
	    # working directory is also HTTP reachable somewhere.
	    $c->addkey('url', text('file://' . $path));
	}
	if ($filename =~ /\/\z/) {
	    # warn of missing subdirectories
	    unless ($path =~ /\/\z/) {
		warn("$fn: directory '" . $c->apath . "' does not exist\n");
		$c->addkey('missing', text '1');
		next;
	    }
	} else {
	    # ensure existing directory names have a trailing /
	    if ($path =~ /\/\z/) {
		$filename .= '/';
		$c->setstr($filename);
	    }
	}
	# set fpath
	if ($c->fpath ne $path) {
	    $c->addkey('fpath', text($path));
	}
	# set path2node
	if (exists $path2node{$path} && $path2node{$path}->nid ne $c->nid) {
	    die("$fn: The navigation-tree nodes ".
		$path2node{$path}->dpath . ' and ' . $c->dpath .
		"\nboth refer to the same file or directory: $path\n".
		"Each page can have only one single position in the tree.\n");
	}
	$path2node{$path} = $c;
	# recurse
	$c->prepare_nodes($fn);
    }
}

=item I<set_global_uconfig(FILENAME)>

Each time a new NavTree is created by find_file, the parameters from
this file will be copied into its root, to set default values (that
can be overridden by the uconfig.txt file in the top-level directory).
This function parses the file, stores its data in a global variable,
and has no return value. This global uconfig.txt file can only contain
parameters; any files or directories that it lists will be removed and
will result in a warning message.

=cut
# global uconfig data
my $global_uconfig;
sub set_global_uconfig {
    my ($fn) = @_;

    $global_uconfig = read_uconfig($fn);
    if (defined $global_uconfig) {
	foreach my $l ($global_uconfig->list) {
	    warn("$fn: list element '" . 
		 $l->print . "' not allowed (ignored)\n");
	    $l->cut;
	}
    }
}

=item I<preprocess_filename(PATH)>

=item I<preprocess_filename(PATH, 'input', 'output')>

Given either an input filename (*-b.html) or output filename (*.html)
or stem (*), return an input filename. The second form causes the
return value to be a list containing both the input and output file
name.

=cut
my @suffixes = ('php', 'htm', 'html');     # the last one is the default
sub preprocess_filename {
    my ($fn, @forms) = @_;
    my $input_fn;

    # if it exists as a directory, make sure it ends in a slash
    $fn .= '/' if $fn !~ /\/\z/ and -d $fn;
    # for directories, find the corresponding index-b.* file.
    if ($fn =~ /\/\z/) {
	die "$fn: directory does not exist\n" unless -d $fn;
	foreach my $suffix (@suffixes) {
	    $input_fn = "${fn}index-b.$suffix";
	    last if -f $input_fn;
	}
    } else {
	if ($fn =~ /-b\.(?:html?|php)\z/i) {
	    # we got an input file
	    $input_fn = $fn; 
	} elsif ($fn =~ s/\.(html?|php)\z//i) {
	    # we got an output file
	    $input_fn = "$fn-b.$1";
	} else {
	    # perhaps we got a stem?
	    foreach my $suffix (@suffixes) {
		$input_fn = "$fn-b.$suffix";
		last if -f $input_fn;
	    }
	}
    }

    return $input_fn unless @forms;
    my @answer = ();
    foreach my $form (@forms) {
	if ($form eq 'input') {
	    push @answer, $input_fn;
	} elsif ($form eq 'output') {
	    my $output_fn = $input_fn;
	    $output_fn =~ s/-b\.(html?|php)\z/.$1/i;
	    push @answer, $output_fn;
	} else {
	    die("unknown form parameter '$form'");
	}
    }

    return $answer[0] unless @forms > 1;
    return @answer;
}


=item I<find_file(PATH)>

Returns for the provided file or directory name PATH a cursor to the
NavTree node representing it. If PATH is already represented by an
existing node, this is just a hash-table lookup. If not, then the
NavTree to which this node belongs is identified and a new note added
to it. The root of the NavTree to which PATH belongs represents the
"oldest" (uppermost) ancestor directory of PATH in an uninterrupted
lineage of ancestor directories that each hold a uconfig.txt file.

If no existing NavTree can be identified, then a new one is created
and all uconfig.txt files along the path from its root to PATH will be
read and added. Further uconfig.txt files, elsewhere in that NavTree,
will be added on demand, whenever the user visits yet unexplored parts
of the tree (via the cl() method).

When adding a new NavTree node, the absolute path associated with it
is stored in parameter 'fpath', unless it can be derrived simply by
concatenating filenames to the nearest ancestor node with an fpath
parameter. In the case of a subdirectory (with associated
index.{html,php} and uconfig.txt), this path simply ends in a slash,
whereas otherwise this path is the path of the associated filename
served to the web browser ("output filename").

=cut
sub find_file($) {
    my ($fn) = @_;

    # get canonical pathname for file or directory $fn
    my $path = abs_path($fn);
    die("Cannot determine absolute path of '$fn'\n") unless defined $path;
    # preprocess pathname
    # strip off default output filename (index.html, etc.)
    for my $index_fn (@index_fn) {
	last if $path =~ s/\/$index_fn\z/\//i;
    }
    # directories should end in a slash
    $path .= '/' if $path !~ /\/\z/ && -d $path;
    
    # does the requested node already exist?
    my $cur = $path2node{$path};
    if (defined $cur) {
	$cur->add_uconfig($path);
	return $cur;
    }

    # if not, scan up towards the root
    my @parents = ();
    my $ppath;
    # preserve filename
    if ($path !~ /\/\z/) {
	unshift @parents, $path;  # save path with trailing filename
	$path =~ s/[^\/]+$//;     # and then strip off the latter
    }
    # scan path along .. or u.. links for as
    # long as there are uconfig.txt files there
  UCONFIG_SCAN: {
      my %beenhere;
      do {
	  # did we encounter this parent before?
	  $cur = $path2node{$path};
	  if (defined $cur) {
	      $cur->add_uconfig($path);
	      $ppath = $path;
	      last UCONFIG_SCAN;
	  };
	  # save canonical path in @parents array
	  unshift @parents, $path;
	  die("Path loop detected:\n" . join("\n", reverse(@parents)) . "\n")
	      if $beenhere{$path}++;
	  # A symlink uorigin/ can be used to point to a directory that the
	  # current directory is meant to replace for the purposes of the
	  # scan of the navigation tree; the usual usage is if a subtree
	  # of a site has been checked out for editing, then the root of the
	  # subtree contains a "uorigin" symlink to the corresponding
	  # directory in the original full tree.
	  while (-l "${path}uorigin" and -d "${path}uorigin/") {
	      my $origin = abs_path("${path}uorigin/") . '/';
	      warn("Symlink overrides a directory that had already been added to navigation tree:\n ${path}uorigin -> $origin\n")
		  if defined $path2node{$origin};
	      $overridepath{$origin} = $path;
	      $path = $origin;
	  }
	  # look for next parent
	  if (-d $path . "u../") {
	      # symlink u../ can be used to replace the current .. directory
	      $path .= 'u../';
	      # get new canonical pathname
	      $path = abs_path($path) . '/';
	  } else {
	      last if $path eq '/'; # stop at root directory
	      $path =~ s/[^\/]+\/$//; # strip off trailing directory (ie., cd ..)
	  }
      } while -f "${path}uconfig.txt";
    }

    # Now @parents contains the paths of all the nodes that we have to add.
    # Process parent directories, starting from the top.
    while ($path = shift @parents) {
	if (exists $path2node{$path}) {
	    $cur = $path2node{$path};
	} else {
	    if (defined $cur) {
		# this node has a parent, but is not reachable from it
		$cur = NavTree->new($cur);
		$cur->setatt('unreachable', '1');
		# if $ppath is a prefix of $path
		if (substr($path, 0, length($ppath)) eq $ppath &&
		    substr($path, length($ppath)) =~ /^[^\/]*.\z/) {
		    # then set $cur->str to be the remaining part of $path
		    $cur->setstr(substr($path, length($ppath)));
		} else {
		    # $path is not a child of $ppath in the
		    # file system, and this break will be represented by
		    # [...] in the output of $cur->dpath()
		    $cur->addkey('fpath', text($path));
		}
	    } else {
		# unknown root, so we need to create a new NavTree here
		$cur = NavTree->new;
		$cur->copyfrom($global_uconfig) if defined $global_uconfig;
		$cur->addkey('fpath', text($path));
	    }
	    $path2node{$path} = $cur;
	}
	$cur->add_uconfig($path);
	$ppath = $path;
    }
    
    return $cur;
}

=back

=head1 METHODS

=over 4

=item I<param(PARAMETER)>

Lookup a parameter string value from a node or the nearest ancestor
that has a value for it. When searching for parameter values, it will
also look any found in the value of a I<noninherit> parameters of the
current node, or in the value of I<onlyinherit> parameters of any
ancestors.

This function is similar to I<paramc>, but returns a string rather
than a PlexTree cursor, or undef if there is no such parameter or it
does not have a string value.

When looking up a parameter whose value is not inherited across a
subtree, use the PlexTree method I<get> instead.

=cut
sub param {
    my ($node, $pname) = @_;
    my $v = $node->paramc($pname);
    return undef unless defined $v;
    return $v->str;
}

=item I<paramc(PARAMETER)>

Lookup a parameter value from a node or the nearest ancestor that has
a value for it (taking into account I<noninherit> and I<onlyinherit>
parameters). This fuction returns a PlexTree cursor to the node that
represents the value of this parameter. If you are just interested in
a string value, use I<param> instead.

When looking up a parameter whose value is not inherited across a
subtree, use the PlexTree method I<cd> instead.

=cut
sub paramc {
    my ($node, $pname) = @_;
    my $v;
    my $n;
    $pname = text($pname); # convert attribute to text compound
    return $v if defined($v = $node->cd($pname));
    # check for attributes that are not inherited to subnodes
    # but apply to the node itself
    if (defined($n = $node->cd('noninherit'))) {
	return $v if defined($v = $n->cd($pname));
    }
    while (defined($node = $node->parent)) {
	# check for attributes that are inherited to subnodes only
	# but do not apply to the node itself
	if (defined($n = $node->cd('onlyinherit'))) {
	    return $v if defined($v = $n->cd($pname));
	}
	return $v if defined($v = $node->cd($pname));
    }
    return undef;
}

=item I<paramn(PARAMETER)>

Lookup a parameter attribute value from a node or the nearest ancestor
that has a value for it. This function returns a PlexTree cursor to
the node that represents the value of this parameter. This function
differs from I<paramc> in that it ignores any I<noninherit> attribute
in this node, as well as any I<onlyinherit> attributes of its
ancestors.

=cut
sub paramn {
    my ($node, $pname) = @_;
    $pname = text($pname); # convert attribute to text compound
    return $node if defined($node->cd($pname));
    while (defined($node = $node->parent)) {
	return $node if defined($node->cd($pname));
    }
    return undef;
}

=item I<fpath()>

=item I<fpath(ATTRIBUTE)>

=item I<fpath(ATTRIBUTE, SUBDIR)>

Returns the absolute filesystem pathname of the current node. This
requires that the node or one of its ancestors (typically $node->top)
has its 'fpath' attribute set correctly. The 'fpath' attribute of the
nearest ancestor node has priority. This method returns undef if no
'fpath' attribute can be found in the current node or any ancestor, or
if the key method returns undef anywhere along the path to the node
whose 'fpath' attribute would be used (meaning that the node cannot
actually be reached through that path, usually because it lives in
some other directory and the ancestry is via uorigin or u.. links). If
parameter ATTRIBUTE is defined, it specifies another attribute name
than 'fpath' (in particular 'url'). With parameter SUBDIR set to 1,
the directory containing the current node will be returned instead.

=cut
sub fpath {
    my ($node, $attribute, $subdir) = @_;
    my $path;
    my $key;
    $attribute = 'fpath' unless defined $attribute;

    # is this node a link?
    if ($node->tag == META && $node->str eq 'link') {
	my $href = $node->getl(0);
	return undef if $href =~ /^(?:[a-z]+:|\/)/; # process only rel. URLs
	my $path = $node->parent->fpath($attribute);
	if (defined $path) {
	    # eliminate .. path components before appending
	    # relative path to base URL (= URL of parent
	    while ($href =~ s/^\.\.\///) {
		$path =~ s/[^\/]+\/$//;
	    }
	    $path .= $href;
	}
	return $path
    }

    my @path = ();
    my $n = $node;
    while (defined $n) {
	if (defined($path = $n->get($attribute))) {
	    $path .= join('', @path);
	    return $path;
	}
	last unless $n->tag == TEXT();
	my $nodename = $n->str;
	# Although HTML files (and not just directories) can have
        # child-nodes in the navigation tree, their filenames will
        # not show up as a path component, because such childnodes
	# reside as siblings in the file system. Same for nosub=1 nodes.
	if (!(@path || $subdir) ||
	    !($n->get('nosub') || $nodename =~ /\.(?:html?|php)$/i)) {
	    unshift @path, $nodename;
	}
	$n = $n->parent;
    }

    return undef;
}

=item I<fdirname()>

=item I<fdirname(ATTRIBUTE)>

Like like $node->fpath(ATTRIBUTE), but with any non-directory suffix
(anything after the last slash) stripped off. This value is useful,
for example, to prefix relative URLs found inside the HTML document
represented by $node.

=cut
sub fdirname {
    my ($node, $attribute) = @_;
    my $path = $node->fpath($attribute);
    return unless defined $path;
    $path =~ s/[^\/]+$//;
    return $path;
}

=item I<fsubdirname()>

=item I<fsubdirname(ATTRIBUTE)>

This is short for $node->fpath(ATTRIBUTE, 1), i.e. returns the
absolute pathname of the directory in which subnodes of $node reside.
Note that this path with be shorter than the result of
$node->fdirname(ATTRIBUTE) if $node->get('nosub') is set.

=cut
sub fsubdirname {
    my ($node, $attribute) = @_;
    return $node->fpath($attribute, 1);
}

=item I<url()>

Returns the URL of the current node. This requires that the node or
one of its ancestors (typically $node->top) has its 'url' attribute
set correctly. The 'url' attribute of the nearest ancestor node has
priority. This method returns undef if no url attribute can be found
in the current node or any ancestor, or if the key method returns
undef anywhere along the path to the node whose url attribute would be
used (meaning that the node cannot actually be reached through that
path, usually because it lives in some other directory and the
ancestry is via uorigin or u.. links).

=cut
sub url {
    my ($node) = @_;
    # is this node a link?
    if ($node->tag == META && $node->str eq 'link') {
	my $href = $node->getl(0);
	return $href if $href =~ /^[a-z]+:/; # return full URLs unmodified;
    }
    my $url = $node->fpath('url');
    if (!defined $url) {
	# warn("Could not determine URL of node " . $node->apath
	#      ."\nso please add 'url' attribute to top-level uconfig.txt\n");
	$url = 'file://' . $node->fpath;  # fallback
    }
    return $url;
}

=item I<rurl(CURRENT)>

Returns the relative URL from node CURRENT to the file or directory
name associated with the node on which this method was invoked. If no
relative URL is possible (because of missing url attributes in the
navtree or because of a difference in domain name), an absolute URL
will be generated instead. Relative URL syntax is defined in RFC 1808.
Can also be called as function NavTree::rurl($href, $current) where
$href is the full destination URL.

=cut
sub rurl($$) {
   my ($node, $current)  = @_;
   my $fulldst;
   if (ref $node) {
       # is this node a link?
       if ($node->tag == META && $node->str eq 'link') {
	   my $href = $node->getl(0);
	   return $href if $href =~ /^[a-z]+:/; # return full URLs unmodified
       }
       # handle nopage situation
       my $nopage;
       while ($nopage = int($node->get('nopage'))) {
	   if ($node->listlen) {
	       # the value of nopage decides, which subnode the link
	       # will go to, e.g. nopage=1 redirects the link to the
	       # first child
	       $nopage = $node->listlen if $nopage > $node->listlen;
	       $node = $node->cl($nopage - 1);
	   } else {
	       warn("Childless node " . $node->dpath .
		    " has nopage=$nopage set\n");
	       return undef;
	   }
       }
       # get node's URL
       $fulldst = $node->url;
   } else {
       # we received a URL string instead of a node reference
       if ($node =~ /^[a-z]+:/) {
	   # $node is already a full URL
	   $fulldst = $node;
       } else {
	   # convert the received relative URL in $node into a full one
	   $fulldst = $current->url;
	   return $node unless defined $fulldst;
	   $fulldst =~ s/[^\/]+$//; # remove any trailing filename
	   # eliminate .. path components before appending
	   # relative path to base URL
	   while ($node =~ s/^\.\.\///) {
	       $fulldst =~ s/[^\/]+\/$//;
	   }
	   $fulldst .= $node;
       }
   }
   my $fullsrc = $current->url;
   my $dst = $fulldst;
   my $src = $fullsrc;
   # fallback alternatives
   return $dst if !defined $src;
   return undef if !defined $dst;
   # strip off any common 'http://domain.name/' prefix
   if ($src =~ /^((?:https?|ftp|file):\/\/[^\/]*\/)/i) {
       my $prefix = $1;
       if (substr($dst, 0, length($prefix)) eq $prefix) {
	   $src = substr($src, length($prefix));
	   $dst = substr($dst, length($prefix));
       } else {
	   return $dst;
       }
   } else {
       return $dst;
   }
   # we now have slash-separated path components left
   my @src = split /\//, $src, -1;
   my @dst = split /\//, $dst, -1;
   # remove common prefix
   while (@src > 1 && @dst && $src[0] eq $dst[0]) {
       shift @src;
       shift @dst;
   }
   # prefix the rest of @dst with the required number of '../'
   $dst = ('../' x (@src - 1)) . join('/', @dst);
   $dst = '.' if $dst eq '';
   # and finally test whether this file actually exists
   my $base = $current->fpath;
   $base =~ s/[^\/]+$//; # remove any trailing filename
   # return the relative URL if the file can be found locally
   return $dst if -e ($base . $dst);
   my $dstb = $dst;
   if ($dstb =~ s/(\.(?:html?|php))$/-b$1/i) {
       # also try the -b source file (which may not yet have been processed):
       return $dst if -e ($base . $dstb);
   }
   # return the full URL if the file cannot be found locally
   # (e.g., because it is not checked out in a
   # repository working directory)
   return $fulldst;
}

# $node->apath() returns absolute path from the top-level directory
# to the file or directory name associated with a node.
# $node->apath('file') adds a default 'index.html' output
# filename to a directory path).
# $node->apath('srcfile') causes the last path component to be
# the ...-b.html source file (if one exists).
# $node->apath('dir') results always in a directory name
# If a path component does not have a corresponding filename
# (and therefore, the path is not actually reachable), that component
# will be represented as '[...]'.
sub apath {
    my ($self, $opt) = @_;
    my @p = $self->path;
    my $last = pop @p;
    @p = ( grep({ !$_->get('nosub') } @p), $last);
    shift @p; # discard root cursor, which has no filename associated
    my $p = join('/', map {
	if ($_->tag == TEXT()) {
	    $_ = $_->str;
	    $_ =~ s/\/\z//;
	    $_;
	} else {
	    '[...]';
	}
    } @p );
    my $fpath = $self->fpath;
    if ($fpath =~ /\/\z/) {
	if ($opt =~ /file$/) {
	    $p .= '/' if length($p);
	    my $fn;
	    for my $index_fn (@indexb_fn, @index_fn) {
		if (-f $fpath . $index_fn) {
		    $fn = $index_fn;
		    $fn =~ s/-b(\.(?:html?|php))$/$1/i;
		    last;
		}
	    }
	    $fn = $index_fn[0] unless defined $fn;
	    $p .= $fn;
	} else {
	    $p .= '/';
	}
    }
    if ($opt eq 'srcfile' && $p =~ /\.(?:html?|php)$/i) {
	my $src = $p;
	$src =~ s/(\.(?:html?|php))$/-b$1/i;
	$p = $src if -e $fpath;
    } elsif ($opt eq 'dir') {
	$p =~ s/[^\/]*$//;
    }
    return $p;
}

=item I<dpath()>

Returns a human-readable form of the path from the top-level directory
to the file or directory name associated with the node. If a path
component does not have a corresponding filename (and therefore, the
path is not actually reachable), that component will be represented as
'[...]'. Path components with nosub=1 attribute are enclosed in square
brackets.

=cut
sub dpath {
    my ($self) = @_;
    my @p = $self->path;
    shift @p; # discard root cursor, which has no filename associated
    my @path;
    my $old_nosub = 0;
    while (my $p = shift @p) {
	push @path, '/' if @path;
	my $nosub = @p &&
	    ($p->get('nosub') ||
	     ($p->tag == TEXT() && $p->str =~ /\.(?:html?|php)$/i));
	if ($nosub && !$old_nosub) {
	    push @path, '[';
	} elsif (!$nosub && $old_nosub) {
	    push @path, ']';
	}
	$old_nosub = $nosub;
	if ($p->tag == TEXT()) {
	    my $f = $p->str;
	    $f =~ s/\/\z//;
	    push @path, $f;
	} else {
	    push @path, '[...]';
	}
    }
    push @path, '/' if $self->fpath =~ /\/\z/;
    return join('', @path);
}

# $node->rpath() returns the relative path from node $current to the
# file or directory name associated with a node.
# $node->rpath($current, 'index-b.html') adds a default filename to a
# directory path.
sub rpath {
    my ($node, $current, $index_fn) = @_;
    my $path = $node->rurl($current);
    if ($path !~ /^[a-z]+:/ &&
	$path =~ /\/\z/) {
	$path .= $index_fn;
    }
    return $path;
}

# try to locate the *-b.(html?|php) source file associated with a node,
# if one exists
sub srcfile {
    my ($self, $opt) = @_;
    my $path = $self->fpath;
    if ($path =~ /\/\z/) {
	for my $index_fn (@indexb_fn, @index_fn) {
	    my $src = $path.$index_fn;
	    if (-f $src) {
		return $src;
	    }
	}
	return $path.$indexb_fn[0]; # fallback if no index file is found
    } else {
	my $src = $path;
	$src =~ s/(\.(?:html?|php))$/-b$1/i;
	$path= $src if -f $src;
    }
    return $path;
}

=item I<title()>

Query the content of the <title> element of a HTML source document and
cache what is found in parameter 'title'. The <title> element is
extracted from the HTML file with a simple regular expression without
using a proper HTML parser, relying on the fact that the <title> and
</title> tags are not ommittable and that both are usually located
within the first few hundred bytes of an HTML file.

=cut
sub title($) {
    my ($self) = @_;
    my $s = $self->get('title');
    return $s if defined $s;
    my $srcfile = $self->srcfile;
    return undef unless defined $srcfile;
    $s = main::html_extract($srcfile, 'title');
    if (defined $s) {
	$s = PlexTree::SGML::sgml_to_utf8($s);
	$self->addkey('title', text($s));
    }
    return $s;
}

=item I<navtitle()>

Like title(), but permit user to override using parameter 'navtitle',
which may be a shortend version of the full page title for compact
presentation in navigation links.

=cut
sub navtitle($) {
    my ($self) = @_;
    return $self->get('navtitle') || $self->title;
}

# read some inode data about owner and last-modified date
sub fstat {
    my ($self) = @_;
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	$atime,$mtime,$ctime,$blksize,$blocks) =
	    stat($self->srcfile);
    $self->addkey('ownername')->setstr((getpwuid($uid))[0]);
    $self->addkey('ownergcos')->setstr((getpwuid($uid))[6]);
    $self->addkey('mtime')->setstr($mtime);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($mtime);
    $self->addkey('mtime_iso_local')->
	setstr(sprintf("%04d-%02d-%02d %02d:%02d",
		       1900+$year, $mon+1, $mday, $hour, $min));
}

# try to extract name of author of the last revision from Subversion metadata
sub svninfo {
    my ($self) = @_;
    return if $^O eq 'MSWin32'; # don't even try this under Windows
    my $fn = $self->srcfile;
    my $dir = $fn;
    $dir =~ s/[^\/]+$//;
    return unless -d $dir . '.svn';
    # proper shell quoting of filename
    $fn =~ s/([\$\`\"\\])/\\$1/g;
    $fn = '"' . $fn . '"';
    # call svn info
    my $cmd = "svn info $fn 2>/dev/null";
    my $info = `$cmd`;
    return if $?;
    $self->addkey('svnauthor')->setstr($1)
	if $info =~ /^Last Changed Author:\s+(.+)$/m;
    $self->addkey('svnrevision')->setstr($1)
	if $info =~ /^Last Changed Rev:\s+(\d+)$/m;
    $self->addkey('svndate')->setstr($1)
	if $info =~ /^Last Changed Date:\s+(\d\d\d\d-\d\d-\d\d \d\d:\d\d):/m;
}

# try to explain the applicable .htaccess ACL in plain English
# (this is still very incomplete, and probably will remain so)
sub access_restrictions($) {
    my ($cur) = @_;
    my $path = $cur->srcfile;
    return unless defined $path;
    $path =~ /^(.*\/)([^\/]*)$/;
    $path = $1;
    my $dest_fn = $2;
    $dest_fn =~ s/-b(\.(?:html?|php))$/$1/i;   # output filename
    my $htaccess;
    return unless open($htaccess, $path . '.htaccess');
    my $order;
    my @allowed = ();
    my $access;
    while (<$htaccess>) {
	# http://httpd.apache.org/docs/2.2/configuring.html#syntax
	while (s/\\$//) { $_ .= <$htaccess>; } # continuation syntax
	s/^\s*(.*)\s*$/$1/; # remove leading and trailing whitespace
	next if /^#/; # skip comments
	if (/^order\s+allow\s*,\s*deny$/i) {
	    $order='allow,deny';
	} elsif (/^order\s+deny\s*,\s*allow$/i) {
	    $order='deny,allow';
	} elsif (/^require\s+(?:user|group)\s+(.*)$/i) {
	    my $list = $1;
	    push @allowed, split(/\s+/, $list);
	} elsif (/^allow\s+from\s+(.*)$/i) {
	    my $list = $1;
	    push @allowed, split(/\s+/, $list);
	} elsif (/^require\s+(?:valid-user)$/i) {
	    push @allowed, 'users with login';
	} elsif (/^<Files\s+(?:(~)\s+)?"(.*?)"\s*>$/i ||
		 /^<Files\s+(?:(~)\s+)?(\S*?)\s*>$/i) {
	    #http://httpd.apache.org/docs/2.2/mod/core.html#files
	    my $isregex = $1;
	    my $filename = $2;
	    if ((!$isregex && ($dest_fn ne  $filename )) || # TODO: fnmatch
		( $isregex && ($dest_fn !~ /$filename/))) {
		# skip content of this <Files> section
		while (<$htaccess>) {
		    while (s/\\$//) { $_ .= <$htaccess>; } # continuation syntax
		    last if /^\s*<\/Files>\s*$/i;
		};
	    }
	} elsif (/^<FilesMatch\s+"(.*?)"\s*>$/i ||
		 /^<FilesMatch\s+(\S*?)\s*>$/i) {
	    # http://httpd.apache.org/docs/2.2/mod/core.html#filesmatch
	    my $regex = $1;
	    if ($dest_fn !~ /$regex/) {
		# skip content of this <FilesMatch> section
		while (<$htaccess>) {
		    while (s/\\$//) { $_ .= <$htaccess>; } # continuation syntax
		    last if /^\s*<\/FilesMatch>\s*$/i;
		};
	    }
	}
    }
    close $htaccess;
    if ($order eq 'allow,deny') {
	$access = 'Access to this page is restricted';
	if (@allowed) {
	    $access .= ' to ' . join(', ', @allowed);
	}
	$access .= '.';
    }
    return $access;
}


=item I<level(DEPTH)>

Go to a specified depth on the current path.

=cut
sub level($$) {
    my ($self, $depth) = @_;
    my $up = $self->depth - $depth;
    return undef if $up < 0;
    return $self->up($up);
}

# go to the first menu entry at a specified depth on the current path
sub startlevel($$) {
    my ($self, $depth) = @_;
    my $l = $self->level($depth-1);
    return unless defined $l;
    return $l->cl(0);
}

=item I<preorder_next_visible()>

Find the "next" page in the navigation tree in preorder, ignoring
nopages and without exposing invisible pages.

=cut
sub preorder_next_visible($) {
    my ($self) = @_;
    
    my $n = $self->cl(0);
    while (defined $n) {
	if ($n->get('invisible')) {
	    $n = $n->next;
	} elsif ($n->get('nopage')) {
	    $n = $n->cl(0);
        } else {
	    return $n;
	}
    }
    do {
	$n = $self->next;
	while (defined $n) {
	    if ($n->get('invisible')) {
		$n = $n->next;
	    } elsif ($n->get('nopage')) {
		$n = $n->cl(0);
	    } else {
		last;
	    }
	}
	return $n if defined $n;
	$self = $self->parent;
    } while (defined $self);
    return undef;
}

1;

=back

[... lots more already implemented methods still need to be documented ...]

=head1 SEE ALSO

PlexTree.pm

=head1 AUTHOR

Both ucampas and this Perl package were developed
by Markus Kuhn <http://www.cl.cam.ac.uk/~mgk25/>.
