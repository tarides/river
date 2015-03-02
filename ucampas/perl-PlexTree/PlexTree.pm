=head1 NAME

PlexTree - a general-purpose hierarchical data model

=head1 SYNOPSIS

  use PlexTree;

  $c = PlexTree->new;

  $c->settag(1);                 $t = $c->tag();
  $c->setstr('test');            $s = $c->str();
  $c->setstr('test', 4);         $s = $c->str(4);
  $c->setstr('test', 4, 0);      $s = $c->str(4, 6);

  $v = $c->addkey('test');
  $c->addkey(binary('test'));
  $c->addkey(c('$test(@4, out="file")'));

  $v = $c->append($t . $s);
  $c->up();

=head1 WARNING

This documentation is not yet ready, please come back later.

=head1 SUMMARY

The PlexTree software architecture is centered around a hierarchical
general-purpose data structure called "compound". The compound data
model can serve as a framework for defining file formats and database
schemata. The PlexTree concept also defines a mechanism for
implementing reusable processing functionality for these compounds,
called "filter". This Perl library provides mechanisms for the
flexible and convenient handling of data in compounds and for
processing them through filters. It was also written to serve as a
reference implementation for the PlexTree concept.

A compound is a recursively defined data structure, a kind of tree of
byte strings. It can be used as a hierarchical general purpose data
structure, particularly suitable as a framework for defining file
formats and database schemata. Each compound consists of a set of
nodes, of which one represents the root of the compound. In addition,
each compound also contains a set of "keys", which are themselves
complete compounds (usually very small ones). The remaining nodes can
be classified into "list elements" and "set elements". Each node N has
associated with it a (possibly empty) list of nodes ("list elements"),
and all nodes in that list have N as their designated parent node.
Each node N further has associated with it a set of key-value pairs
("directory"), where each key is a compound (with its own root node)
and the value is a set-element node. Both the list-element and the
set-element nodes again have their respective own list of nodes and
set of key-value pairs associated with them. This way, each node in a
compound can be considered to form the root of a subtree that again
has all of the characteristics of a compound (except that its root has
a parent node). All the key compounds listed in the directory of a
particular node differ pairwise in at least one of their nodes.
Therefore, the combination of a node and a key compound found in its
directory uniquely defines one value node. The distinction between
list nodes and set nodes clarifies for each node whether its relative
position among its siblings matters (as it does in a list) or not
(like in a set).

Each node of a compound also contains an arbitrary-length byte string,
along with a "tag". A tag is a number in the range 0 to 15 and can be
used to distinguish different types of strings.

=head1 DETAILS

Each compound node consists of five elements:

=over 4

=item I<String>

an arbitrary-length sequence of 8-bit bytes

=item I<Tag>

a number in the range 0 to 15 that distinguishes several kinds of
I<string>

=item I<Directory>

a mapping of I<key> compounds to I<value> compounds

=item I<Key Set>

a subset ("visible keys") of the set of key PlexTrees in the directory

=item I<List>

a sequence of zero or more PlexTrees

=back

Tags in the range 0 to 7 are meant to be used for strings that are
meant to be interpreted in ASCII or UTF-8, while tags 8 to 15 are for
other data encodings. In particular, the following use of tag numbers
is suggested

=over 4

=item 0

I<control string>: reserved for interaction with PlexTree filter modules

=item 1

I<text string>: the default tag for general-purpose plaintext strings

=item 2

I<meta string>: used where a plain-text string needs to be
distinguished from a I<text string> (when an SGML/XML document is
loaded as a compound, I<meta strings> are used to distinguish element
names for normal text)

=item 3

I<hyper string>, used where some text needs to be distinguished from a
text or meta text string

=item 4-7

reserved for other string types representing UTF-8 plaintext

=item 8-12

reserved for other string types in non-UTF-8 encodings

=item 13

I<binary number>: binary (base 2) integer or floating-point number
represented in a special sortable encoding.

=item 14

I<binary string>: general-purpose string for non-plaintext data
(typically represented in hexadecimal)

=item 15

I<list position>: to encode integer numbers (in a special sortable
representation) that denote I<list> positions. These can be used in
paths through compounds to distinguish list positions from any I<keys>.

=back

The PlexTree class defined by this package provides not only a
container for storing a compound, but also a "cursor" that marks a
current node position inside a compound. Therefore, the methods
provided by this class not only allow you to poke and modify the
compound, but also to walk over it.

=head1 METHODS

The following methods can be invoked on an PlexTree object:

=over 4

=cut

# Superclass of all compound interface implementations

# All PlexTree objects are arrays [$parent, $kref, $nosub, $env, ...]
# that represent a current node position ("cursor") within a compound.
# The array elements are:
#
# $parent = $self->[0] either:
#                        - a reference pointing to the cursor position
#                          of the parent node of the current node
#                          [this is always a reference to a PlexTree
#                          subclass, but might not be a PlexTreeMem
#                          object in case the PlexTreeMem root was
#                          generated with PlexTreeMem->new($parent, $key)]
#                        - undef if the current node is the root
#
# $kref = $self->[1]   either:
#                        - a reference pointing to the CRF-S encoded key
#                          that led to the current node
#                        - an integer with the current node's list position
#                        - undef if the current node is the root or is
#                          not reachable in any way from its parent
#
# $nosub = $self->[2]  either:
#                        - undef if no substitution filter is enabled
#                        - {} if all substitution filters apply
#                        - { 'a' => undef, 'b' => undef } if substitution
#                          filters with control strings 'a' and 'b'
#                          are disabled for this cursor
#
# $env  = $self->[3]   (reserved for a reference to the environment
#                      associated with this cursor position)
#
# $self->[4] and beyond contain sub-class specific data that is not accessed
# by any of the routines in the PlexTree package.
#
# This class provides only methods that can be implemented entirely
# using either the above fields or on top of the basic compound
# interface, independent of how the compound is actually represented
# in memory. Examples are methods for copying (sub)compounds or for
# converting them to specific representations. The actual compound
# query and editing capabilities are entirely provided by subclasses.
#
# This class intercepts all cd() and cl() method invocations, and maps
# them to corresponding "raw" cd_r() and cl_r() methods in the
# subclass that actually implements the tree navigation and editing
# facilities. Those cd_r() and cl_r() methods remain ignorant of anything
# to do with activation of filters, which is handled for all subclasses
# in the cd() and cl() methods here in the superclass.

# Subclasses of PlexTree are expected to provide at least the following
# 11 methods for read access:
#
#  str, tag, listlen, dirlen, cd_r, cl_r, keys, list

package PlexTree;

use strict;
use bytes;
no locale;
use Carp;
require Exporter;

our @ISA = qw(Exporter);
# symbols to export
our @EXPORT = qw(CTRL TEXT META HYPER SUPER ULTRA PARA TRANS
		 ctrl text meta hyper super ultra para trans
		 BINARY LISTPOS MINTAG MAXTAG
		 binary listpos tstring c);

# Tag value constants
use constant MINTAG  =>  0;  # lowest permitted tag value
use constant CTRL    =>  0;  # control string
use constant TEXT    =>  1;  # normal plain-text string
use constant META    =>  2;  # meta string
use constant HYPER   =>  3;  # hyper string
use constant SUPER   =>  4;  # super string
use constant ULTRA   =>  5;  # ultra string
use constant PARA    =>  6;  # para string
use constant TRANS   =>  7;  # trans string
use constant BINARY  => 14;  # binary string
use constant LISTPOS => 15;  # list position
use constant MAXTAG  => 15;  # highest permitted tag value

# Filters are subroutines of the form
#
#   $value = filter($parent, $kref, $arg, $type)
#
# They return a PlexTree object. The filter was activated by the
# string found at compound $arg, where it may find further parameters.
#
# There are two types of filter invocation:
# 
#   - Augmentation filter ($type = 'a'):
#     It is invoked by the compound user descending from $parent with
#     cd() into an invisible key whose control string identifies the
#     filter to be activated.
#
#   - Substitution filter ($type eq 's'):
#     It is invoked is the compound user descends into a compound
#     with a visible control string that identifies the filter
#     to be activated.
#
# In other words, the activation of an augmentation filter is in the
# hands of a compound user, whereas the activation of a substitution
# filter is ultimately caused by a compound provider.
#
# The parameters passed on to a filter are chosen to facilitate
# that the same routine can act both as an augmentation and
# substitution filter. Where a filter requires an "input compound"
# to process, this is usually $parent in the case of an augmentation
# filter and $arg->cl(0) in the case of a substitution filter

# Augmentation filters (many of which are implemented in other
# packages) have to register themselves by calling
#
#   register_augmentation_filter($fname, \&filter)
#
# As a result, whenever a method call $node->cd($key) happens
# where $key->tag == CTRL and $key->str eq $fname, and $node has no
# visible control key of that name, then the function
#
#   $value = filter($node, $kref, $key, 'a')
#
# will be called and will be expected to return a PlexTree subclass
# object that represents the value to be returned by $node->cd($key).
# Its implementation should ensure that $node->cd($key)->up() is
# equivalent to $node. The value $kref is a reference to the result of
# $key->crfs.

my %augmentation_filter = ();

sub register_augmentation_filter {
    my ($fname, $subroutine) = @_;

    warn("Double registration of augmentation filter '$fname'")
	if exists $augmentation_filter{$fname};
    $augmentation_filter{$fname} = $subroutine;
    return;
}

# Substitution filters (many of which are implemented in other
# packages) have to register themselves by calling
#
#   register_substitution_filter($fname, \&filter)
#
# As a result, whenever a method call $d = $node->cd($key) would lead to
# a new node $d with $d->tag == CTRL and $d->str eq $fname, then
# the function
#
#   $value = filter($node, $kref, $d, 's')
#
# will be called and will be expected to return a PlexTree subclass
# object that represents whatever the filter wants the user to see
# instead of $d, and this will be returned by $node->cd($key). The
# filter implementation should ensure that $node->cd($key)->up() is
# equivalent to $node. A single $node->cd($key) call can invoke
# several substitution filters at once if the node returned by the
# first filter invoked again is a control string. The value $kref is a
# reference to the result of $key->crfs in case of a cd() operation,
# or the integer list position in case of a cl() operation.

my %substitution_filter = ();

sub register_substitution_filter {
    my ($fname, $subroutine) = @_;

    warn("Double registration of substitution filter '$fname'")
	if exists $substitution_filter{$fname};
    $substitution_filter{$fname} = $subroutine;
    return;
}

# Register a function as both augmentation and substitution filter
sub register_filter {
    &register_augmentation_filter;
    &register_substitution_filter;
    return;
}

our $trace=0;
# print a stack trace for debugging purposes
sub trace($) {
    return unless $trace;
    my ($s) = @_;
    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask);
    print "$s:\n";
    my $i = 0;
    while (($package, $filename, $line, $subroutine, $hasargs,
	    $wantarray, $evaltext, $is_require, $hints, $bitmask)
	   = caller($i++)) {
	print "  $filename:$line:$subroutine\n";
    }
}

# Turn an exception compound returned by a query into
# a list of printable text messages
sub print_error {
    my ($err, @p) = @_;
    my $src;

    if ((@p & 1) == 1) {
	# sole parameter (or first parameter in odd list)
	# is interpreted as source file name
	$src = shift @p;
    }
    
    my %p = @p;

    unless (Scalar::Util::blessed($err) && $err->isa('PlexTree')) {
	# the exception seems to be just a string
	return "$src: $err" if defined $src;
	return $err;
    }

    my $t = '';
    my $l;
    my $row = $err->get('errrow') - $p{skiprows};
    my $col = $err->get('errcol');
    my $path;

    if ($err->tag == TEXT) {
	if (defined $src) {
	    $t .= "$src:";
	    $t .= "$row:$col:" if defined $row && defined $col;
	} elsif ($path = $err->print_path) {
	    $t .= "$path:";
	}
	$t .= $err->str;
	if ($l = $err->get('line')) {
	    $t .= " in";
	    $t .= " line $row" if defined $row;
	    $t .= ":\n" . $l . "\n";
	    my $col;
	    if ($col = $err->cd('errcol')->str) {
		# print whitespace of equal width to prefix, followed by ^
		while ($col > 1 && $l =~ s/^(.)//) {
		    my $c = $1;
		    if ($c =~ /^\s$/) {
			$t .= $c;
		    } else {
			$t .= ' ';
		    }
		    $col--;
		}
		$t .= "^\n";
	    }
	} else {
	    $t .= "\n";
	}
	return ($t);
    } else {
	return map { $_->print_error($src) } $err->values;
    }
}

# if someone wants a new PlexTree object, give them a PlexTreeMem object
sub new {
    return PlexTreeMem->new;
}

# query the length of the string
sub len {
    my $self = shift;
    return length($self->str);
}

=item I<cd(LIST)>

Descends along the given path into dictionary entries and activates
filters where necessary. Returns the cursor position reached at the
end of the LIST path, or undef if that path does not exist. LIST must
contain one or more PlexTree objects, the key values along the path
to be descended.

=cut
sub cd {
    my ($self, @keys) = @_;
    my $d;
    my $kref;
    my $fname;

    foreach my $key (@keys) {

	# if we got a text string -> convert to compound
	$key = c($key) if ref $key eq '';

	if ($key->tag == LISTPOS) {
	    die("... to be implemented ...");
	    $self = $self->cl(0000);
	} else {

	    my $d = $self->cd_r($key);
    
	    # check for augmentation filter
	    if (!defined($d) && $key->tag == CTRL) {
		if (exists $augmentation_filter{$fname = $key->str}) {
		    # trace("AUGMENTATION FILTER: $fname");
		    $kref = $key->crfs;
		    $d = &{$augmentation_filter{$fname}}($self, \$kref,
							 $key, 'a');
		}
	    }

	    return undef unless defined $d;

	    # invoke substitution filter(s) where applicable
	    if (defined $self->[2]) {
		while ($d->tag == CTRL &&
		       exists $substitution_filter{$fname = $d->str} &&
		       !exists $self->[2]->{$fname}) {
		    # trace("SUBSTITUTION FILTER: $fname");
		    $kref = $key->crfs unless defined $kref;
		    $d = &{$substitution_filter{$fname}}($self, \$kref,
							 $d, 's');
		}
	    }
	    
	    $self = $d;
	}

    }

    return $self;
}

=item I<cl(LIST)>

Descends along the given path into list elements and activates
filters where necessary. Returns the cursor position reached at the
end of the LIST path, or undef if that path does not exist. LIST must
contain one or more integer values, the list positions values along
the path to be descended.

=cut
sub cl {
    my ($self, @pos) = @_;
    my $fname;

    foreach my $pos (@pos) {
	my $d = $self->cl_r($pos);
	return undef unless defined $d;

	# invoke substitution filter(s) where applicable
	if (defined $self->[2]) {
	    while ($d->tag == CTRL &&
		   exists $substitution_filter{$fname = $d->str} &&
		   !exists $self->[2]->{$fname}) {
		$d = &{$substitution_filter{$fname}}($self, $pos, $d, 's');
	    }
	}
	$self = $d;
    }

    return $self;
}

=item I<list()>

Calls cl() for each list element node and returns an array of the
resulting cursors.

=cut
sub list {
    my ($self) = @_;
    my $node = $self->[4];  # current node from cursor
    my $listlen = $self->listlen;
    my @list;
    $#list = $listlen - 1; # preallocate final array size
    for (my $i = 0; $i < $listlen; $i++) {
	$list[$i] = $self->cl($i);
    }
    return @list;
}

=item parent()

Returns the cursor position of the parent node, or undef if the current
node is already the root.

=cut
sub parent {
    my ($self) = @_;

    return $self->[0];
}

=item key()

Returns the key (or listpos value) that led to this node, or undef if
we are at the root.

=cut
sub key {
    my ($self) = @_;
    return unless defined $self->[1];
    if (ref $self->[1]) {
	return PlexTree->new->copyfrom_crfs(${$self->[1]});
    } else {
	return listpos($self->[1]);
    }
}

=item pos()

Returns the current list position as an integer value, or undef if we are
not currently in a list element.

=cut
sub pos {
    my ($self) = @_;
    my $kref = $self->[1];

    return undef unless defined $kref;
    return undef if ref $kref;
    return $kref;
}

=item newroot()

Returns a cursor that points to the same node as the current cursor,
but that believes it is at depth 0 and has forgotten about any parents
that the node ever had. (This may trigger the garbage collection of
any ancestors that are not kept alive by other cursors. This operation
does not copy the subtree, which can still be entered from any
surviving ancestor nodes.)

=item newroot($parent, $kref)

Returns a cursor that points to the same node as the current cursor,
but that believes to be a child of $parent reached via key $kref,
where $parent is another cursor and $kref is either a reference
pointing to the CRF-S encoded key that "led" to the current node,
or an integer with the current node's list position. Note that the
node does not actually become reachable this way, i.e. the content of
$parent is not changed.

=cut
sub newroot() {
    my ($self, $parent, $kref) = @_;
    my @new = @$self;
    $new[0] = $parent;
    $new[1] = $kref;
    return bless \@new => ref($self);
}

=item raw()

Returns a copy of the current cursor that has all substitution filters
deactivated.

=cut
sub raw {
    my ($self) = @_;
    my @new = @{$self};
    $new[2] = undef;  # $nosub = undef
    return bless \@new => ref $self;
}

=item cooked()

Returns a copy of the current cursor that has all substitution filters
activated.

=cut
sub cooked {
    my ($self) = @_;
    my @new = @{$self};
    $new[2] = {};  # $nosub = undef
    return bless \@new => ref $self;
}

=item I<nosub(LIST)>

Returns a copy of the current cursor that has the substitution filters
named in LIST deactivated. The LIST elements must be Perl strings.

=cut
sub nosub {
    my ($self, @fnames) = @_;
    my @new = @{$self};
    foreach my $fname (@fnames) {
	$new[2]->{$fname} = undef;
    }
    return bless \@new => ref $self;
}

=item I<up(N)>

Returns a copy of the current cursor that is N levels closer to the
root, or the root itself if we are not that deep. N must be an integer.
Calling up() equals calling up(1), and calling up(1) equals
calling parent().

=cut
sub up {
    my ($self, $levels) = @_;
    $levels = 1 unless defined $levels;
    while (defined $self && $levels--) {
	$self = $self->parent;
    }
    return $self;
}

=item top()

Return a cursor for the root of this tree.

=cut
sub top {
    my ($self) = @_;
    my $d;

    while (defined($d = $self->parent)) {
	$self = $d;
    }
    return $self;
}


=item next()

Return the next list element, or undef if we are in the last list
element or not in a list element at all.

=cut
sub next {
    my ($self) = @_;
    my $pos = $self->pos;

    return $self->parent->cl($pos+1) if defined $pos;
    return;
}

=item prev()

Return the previous list element, or undef if we are in the first list
element or not in a list element at all.

=cut
sub prev {
    my ($self) = @_;
    my $pos = $self->pos;

    return $self->parent->cl($pos-1) if defined $pos;
    return;
}

=item preorder_next()

Return the next node in a pre-order traversal of the list tree, or
undef if this was the last node of the tree.

=cut
sub preorder_next($) {
    my ($self) = @_;
    my $d;

    $d = $self->cl(0);
    return $d if defined $d;
    do {
	$d = $self->next;
	return $d if defined $d;
	$self = $self->up;
    } while (defined $self);
	
    return undef;
}

=item depth()

Return at how many levels below root the current node is located.

=cut
sub depth {
    my ($self) = @_;
    my $depth = 0;
    while (defined($self = $self->parent)) { $depth++ }
    return $depth;
}

=item path()

Return an array of all cursors along the path.

=cut
sub path {
    my ($self) = @_;
    my @path = ();
    
    while (defined $self) {
	unshift @path, $self;
	$self = $self->parent;
    }
    return @path;
}

=item values()

Return an array of all cursor positions in values associated with
visible keys of the current node.

=cut
sub values {
    my ($self) = @_;
    return map { $self->cd($_) } $self->keys;
}

# return list key/value pair strings where the key is a text string,
# with undef for non-textstring values
sub textkvpairs {
    my ($self) = @_;
    my @h = ();
    foreach my $k ($self->keys) {
	next unless $k->tag == TEXT;
	my $v = $self->cd($k);
	push @h, $k->str; 
	if ($v->tag == TEXT) {
	    push @h, $v->str;
	} else {
	    push @h, undef;
	}
    }
    return @h;
}

# test whether the current position is on a path
sub ispath {
    my $self = shift;
    return $self->len == 0 && $self->tag == CTRL && 
	$self->dirlen == 1 && $self->listlen == 0;
}

=item isempty()

Return 1 if the current node has tag value 0, an empty byte string,
and neither list elements nor visible keys. Otherwise return 0.

=cut
sub isempty {
    my $self = shift;
    return $self->len == 0 && $self->tag == CTRL && $self->isleaf;
}

# convert the attributes and list elements of a note into a simple
# Perl hash table, which can be used by filters to check what options
# have been requested
sub options {
    my ($self, $includelist) = @_;
    my $opt = {};

    # process set elements
    foreach my $o ($self->keys) {
	if ($o->tag == TEXT && $o->isleaf) {
	    my $v = $self->cd($o);
	    $opt->{$o->str} = $v->isempty || $v->str;
	}
    }
    if ($includelist) {
	# process flat text list elements as flags
	foreach my $o ($self->list) {
	    if ($o->tag == TEXT && $o->isleaf) {
		$opt->{$o->str} = 1;
	    }
	}
    }
    return $opt;
}

# lookup the text string in the value of a text key
sub get {
    my ($self, @keys) = @_;
    my $c = $self->cd(@keys);
    return undef unless defined $c;
    return undef unless $c->tag == TEXT;
    return $c->str;
}

# lookup the text string in the value of a list element
sub getl {
    my ($self, @pos) = @_;
    my $c = $self->cl(@pos);
    return undef unless defined $c;
    return undef unless $c->tag == TEXT;
    return $c->str;
}

# return an array of cursors to all the leaves of the compound
# that can be reached through visible keys from the current position
# on downwards
sub leaves {
    my ($self) = @_;

    return $self if $self->dirlen == 0;
    my @leaves = ();
    foreach my $v ($self->values) {
	push @leaves, $v->leaves;
    }
    return @leaves;
}

# some default routines for subclasses that have no childnodes
sub listlen { return 0; }
sub dirlen  { my @l = $_[0]->keys; return scalar @l; }
sub isleaf  { return $_[0]->dirlen == 0 && $_[0]->listlen == 0; }
sub cd_r    { return; }
sub cl_r    { return; }
sub keys    { return (); }

# return printable plaintext representation
# options:
#   print(oneline => 1)   do not insert any linefeeds
sub print {
    my $self = shift;
    my $p = PlexTreeMem->new;
    $p->settstr(CTRL, 'textenc');
    while (@_) { $p->addkey(shift)->setstr(shift); }
    return $self->cd($p)->str;
}

# return printable plaintext representation of the current path
sub print_path {
    my $self = shift;
    my @path = $self->path;
    shift @path;  # remove root cursor
    return join('/', map { $_->key->print(oneline => 1) } @path );
}

sub stringify {
    { local $trace = 1;
      trace("Did you really want to stringify a PlexTree object here?"); }
    return $_[0]->print(oneline => 1);
}

# using overload causes unexplained dramatic slowdown on Fedora 7
#use overload q("") => \&stringify;

# perform a PlexTree transaction
sub query($$$$) {
    my ($self, $q, $res, $err) = @_;

    if (!$q->dirlen) {
	# we have reached a leaf of the query -> copy rest from here
	if (!defined eval {
	    $res->copyfrom($self);
	}) {
	    # exception occurred during copy
	    # create in $err path to the current location in $self
	    my $l = $err;
	    my @path = $self->path;
	    shift @path; # drop root cursor
	    foreach my $c (@path) {
		$l = $l->addkey($c->key);
	    }
	    # add error message at that location
	    if (ref $@ && $@->isa('PlexTree')) {
		# exception is a compound
		$l->copyfrom($@);
	    } else {
		# exception is plain text
		chomp $@;
		$l->setstr($@);
	    }
	}
    } else {
	foreach my $k ($q->keys) {
	    my $v;
	    my $qchild = $q->cd($k);
            if (!defined eval {
		# descend along key into source compound
		$v = $self->cd($k);
		die("no such key\n") if !defined $v;
		# we descended successfully into the source compound
		# continue recursion
		$v->query($qchild, $res->addkey($k), $err);
	    }) {
		# exception occurred (e.g., key does not exist)
		# create in $err path to the current location in $self
		my $l = $err;
		my @path = $qchild->path;
		shift @path; # drop root cursor
		foreach my $c (@path) {
		    $l = $l->addkey($c->key);
		}
		# add error message at that location
		if (ref $@ && $@->isa('PlexTree')) {
		    # exception is a compound
		    $l->copyfrom($@);
		} else {
		    # exception is plain text
		    chomp $@;
		    $l->setstr($@);
		}
	    }
	}
    }
    # anything useful we can do with list elements of queries?
}

# Replace everything from the current node on downwards
# with the provided compound
sub set($$) {
    my ($self, $src) = @_;

    # if we got a text string -> convert to compound
    $src = c($src) if ref $src eq '';

    $self->clear->copyfrom($src);
    return $self;
}

# Copy the provided compound from its cursor position on downwards
# into the $self node (which should be empty).
sub copyfrom {
    my ($self, $src) = @_;

    $self->settstr($src->tag, $src->str);
    $self->copyfrom_dir($src);
    $self->copyfrom_list($src);
    return $self;
}

# Copy the directory content of the provided node from its cursor
# position on downwards into the $self node. Ignore the string and
# list at that node (but not further down).
sub copyfrom_dir {
    my ($self, $src) = @_;

    # copy elements of key/value set
    foreach my $k ($src->keys) {
	$self->addkey($k)->copyfrom($src->cd($k));
    }
    return $self;
}

# Append the list content of the provided compound from its cursor
# position on downwards to the list of $self node.
sub copyfrom_list {
    my ($self, $src) = @_;

    # copy list elements
    my $ll = $src->listlen();
    for (my $i = 0; $i < $ll; $i++) {
	$self->append()->copyfrom($src->cl($i));
    }
    return $self;
}

# combine copyfrom_dir and copyfrom_list
sub copyfrom_sub {
    my ($self, $src) = @_;
    $self->copyfrom_dir($src);
    $self->copyfrom_list($src);
    return $self;
}

# Compare this compound ($a) with the provided compound $b, both from the
# cursor position on downwards.
#
# Result: -1 : $a < $b
#          0 : $a = $b
#          1 : $a > $b
#
# The order relationship used is the canonical order that is also
# the base for the definition of CFR-S.
# Therefore: $a->cmp($b) == ($a->crfs cmp $a->crfs)
sub cmp {
    my $a = shift;
    my $b = shift;
    my $r;

    $r = $a->tag cmp $b->tag;
    return $r if $r;
    $r = $a->str cmp $b->str;
    return $r if $r;
    my $ia = -2 * $a->dirlen();
    my $ib = -2 * $b->dirlen();
    # compare key/value pairs
    for (; $ia < 0 && $ib < 0; $ia++, $ib++) {
	$r = $a->cl($ia)->cmp($b->cl($ib));
	return $r if $r;
    }
    $r = -($ia cmp $ib);
    return $r if $r;
    my $la = $a->listlen();
    my $lb = $b->listlen();
    # compare list elements
    for ($ia = 0, $ib = 0; $ia < $la && $ib < $lb; $ia++, $ib++) {
	$r = $a->cl($ia)->cmp($b->cl($ib));
	return $r if $r;
    }
    $r = $la cmp $lb;
    return $r;
}

# using overload caused unexplained dramatic slowdown on Fedora 7
#use overload q(cmp) => \&cmp;

=item I<match(MATCH)>

Returns 1 if the current node has the same tag and string value as
MATCH and if, in addition, all keys of MATCH also appear with the
respective same value in the current node. Returns 0 otherwise. (List
elements of both the current node and of MATCH are ignored by this
operation.)

=cut

sub match($) {
    my ($self, $match) = @_;
    
    return 0 unless defined $match;

    # if we got a text string -> convert to compound
    $match = PlexTree::c($match) if ref $match eq '';

    return 0 unless $self->tag == $match->tag && $self->str eq $match->str;
    
    my @keys = $match->keys;  
    my @values = $match->values;
    
    foreach my $k (@keys) {
	my $v = $self->cd($k);
	return 0 unless defined $v;
	return 0 unless $v->cmp(shift @values) == 0;
    }
    
    # we have a match
    return 1;
}

=item I<lfind(MATCH, NTH, MAXDEPTH)>

Traverses sublists in preorder and returns the NTH (NTH=0 means first)
cursor position that has the same tag, string, keys and values as
MATCH (but may have additional keys). If MATCH is undefined, any list
element will match. If NTH is 'all', then an array of cursor position
of all matching nodes is returned. If MAXDEPTH is specified, then the
recursion is limited to that depth level.

=cut
sub lfind($$$$$$) {
    my ($self, $match, $nth, $maxdepth) = @_;

    my $tag;
    my $str;
    my @keys;
    my @values;
    my $depth = 0;
    my @all;

    if (defined $match) {
	# if we got a text string -> convert to compound
	$match = PlexTree::c($match) if ref $match eq '';

	$tag = $match->tag;	  
	$str = $match->str;	  
	@keys = $match->keys;  
	@values = $match->values;
    }
    
  LISTELEM:
    while (1) {
	if ((!defined $tag || $self->tag == $tag) &&
	    (!defined $str || $self->str eq $str)) {
	    my $i = 0;
	    foreach my $k (@keys) {
		my $v = $self->cd($k);
		next LISTELEM unless defined $v;
		next LISTELEM unless $v->cmp($values[$i++]) == 0;
	    }
	    # we have a match
	    return $self unless defined $nth;
	    if ($nth eq 'all') {
		push @all, $self;
	    } elsif ($nth > 0) {
		$nth--;
	    } else {
		return $self;
	    }
	}
    } continue {
	# goto next element in preorder
	my $d;
	if ((!defined $maxdepth || $depth < $maxdepth)
	    && defined($d = $self->cl(0))) {
	    $depth++;
	    $self = $d;
	} else {
	    while (1) {
		$d = $self->next;
		if (defined $d) {
		    $self = $d;
		    last;
		} else {
		    if ($depth == 0) {
			return @all if $nth eq 'all';
			return undef;
		    }
		    defined ($self = $self->parent)
			|| die("this should never happed");
		    $depth--;
		}
	    }
	}
    }
}

# CRF-S functions

use constant TAGPAD => 16;

# Copy the compound provided as a CRF-S string into the $self
# node (which should be empty from its cursor position downwards).
sub copyfrom_crfs {
    my ($self, $src) = @_;

    if ($self->_copyfrom_crfs(\$src, 0)) {
	use Data::Dumper; $Data::Dumper::Useqq = 1;
	print STDERR Dumper([$src], ['src']);
	die("PlexTree:copy_crfs: Unexpected byte at position " .
	    pos($src) ."!\n");
    }
    return $self;
}

# Recursive auxiliary function for copy_crfs
#
sub _copyfrom_crfs {
    my ($self, $src, $minterm) = @_;
    my $t;

    # read tag + string
    if ($$src =~ /\G([^\x00])((?:[^\x00]+|\x00\xff)*)/gc) {
	my $tag = unpack('C', $1) & 15;
	my $s = $2;
	return 1 unless $tag >= 0 && $tag <= 15;
	$s =~ s/\x00\xff/\x00/g;
	$self->settstr($tag, $s);
    } else {
	$self->settstr(CTRL, '');
    }
    return 0 if $$src =~ /\G\z/;
    $t = _terminates($src, $minterm);
    return 1 unless defined $t;
    return 0 if $t <= $minterm;
    
    # look for set elements
    while ($t == $minterm + 2) {
	# read key
	my $k = PlexTreeMem->new;
	return 1 if $k->_copyfrom_crfs($src, $minterm + 2);
	# read value
	return 1 if $self->addkey($k)->_copyfrom_crfs($src, $minterm + 2);
	return 0 if $$src =~ /\G\z/;
	$t = _terminates($src, $minterm);
	$t = $minterm + 2 unless defined $t;
	return 0 if $t <= $minterm;
    }
    # look for list elements
    while ($t == $minterm + 1) {
	return 1 if $self->append->_copyfrom_crfs($src, $minterm + 1);
	return 0 if $$src =~ /\G\z/;
	$t = _terminates($src, $minterm);
	$t = $minterm + 1 unless defined $t;
	return 0 if $t <= $minterm;
    }
    return 1; # encountered unexpectedly high terminator
}

# If /\G/ in $$src starts a level-$i terminator, then this function returns
# $i. If $i >= $minterm, then it also advanced \G beyond the terminator.
# If there is no terminator, it returns undef and leaves $$src unmodified.
sub _terminates {
    my ($src, $minterm) = @_;
    my $oldpos = pos $$src;

    if ($$src =~ /\G\x00(\xff*)([^\xff])/gc) {
	my $i = 255 * length($1) + unpack('C', $2);
	pos($$src) = $oldpos unless $i >= $minterm;
	return $i;
    }
    return undef;
}

# Provide serialization in CRF-S format, the sortable encoding of a compound
sub crfs {
    my ($self) = @_;
    my ($s, $tag);

    if (!ref $self) {
	# we got just a string ...
	return '' if $self eq '';
	$self =~ s/\x00/\x00\xff/g;
	return "\x11" . $self;
    }

    return $self->_crfs(0);
}

# Recursive auxiliary function for crfs(), produces a CRF-S serialization
# in which the lowest terminator is at level $minterm, and which lacks
# the final terminator (which the caller should later add at level
# $minterm or below, unless the end of the CRF-S string has been reached)
sub _crfs() {
    my ($self, $minterm) = @_;
    my ($i, $t);
    my $s = '';

    if ($self->tag > 0 || $self->len) {
	$s = pack('C', $self->tag | TAGPAD);
	$t = $self->str;
	$t =~ s/\x00/\x00\xff/g;
	$s .= $t;
    }

    # key/value set
    my $sl = $self->dirlen();
    for ($i = -2 * $sl; $i < 0; $i++) {
	$s .= _terminator($minterm + 2) . $self->cl($i)->_crfs($minterm + 2);
    }

    # list elements
    my $ll = $self->listlen();
    for ($i = 0; $i < $ll; $i++) {
	$s .= _terminator($minterm + 1) . $self->cl($i)->_crfs($minterm + 1);
    }

    return $s;
}

# Return a level-$i terminator string, as used in CRF-S. Properties
# of terminators:
#
#  - have the form /\x00(\xfe\xff*)?[\x00-\xfe]/
#  - the sum of all bytes in a terminator equals its level
#  - are self terminating
#  - sort/cmp according to their level
#  - sorts before any string in which \x00 is always followed by \xff
sub _terminator {
    my ($i) = @_;
    my $t = "\0";
    if ($i > 0xfe) {
	$t .= "\xfe";
	$i -= 0xfe;
    }
    while ($i >= 0xff) {
	$t .= "\xff";
	$i -= 0xff;
    }
    # now we have $i < 0xff
    $t .= pack('C', $i);
}

# Convert a listpos string into the corresponding integer value
sub get_listpos {
    my $self = shift;

    die("... todo ...");
}

# Set the string to be a listpos value
sub set_listpos {
    my ($self, $i) = @_;
    if ($i >= 0) {
	if ($i < 0x40) {
	    $self->settstr(LISTPOS, pack("C", 0x80 | $i));
	} elsif ($i < 0x1000) {
	    $self->settstr(LISTPOS, pack("n", 0xc000 | $i));
	} elsif ($i < 0x10000000) {
	    $self->settstr(LISTPOS, pack("N", 0xd000_0000 | $i));
	} else {
	    die("value too high for listpos encoding");
	}
    } else {
	# $i < 0
	if ($i > -0x40) {
	    $self->settstr(LISTPOS, pack("C", 0x80 | ($i ^ 0x3f)));
	} elsif ($i > -0x1000) {
	    $self->settstr(LISTPOS, pack("n", 0xc000 | ($i ^ 0x0fff)));
	} elsif ($i > -0x10000000) {
	    $self->settstr(LISTPOS, pack("N", 0xd0000000 | ($i ^ 0x0fff_ffff)));
	} else {
	    die("value too low for listpos encoding");
	}
    }
    return;
}



# some useful exported subroutines:

# constructors for simple string compounds
sub ctrl($)    { PlexTree->new->settstr(CTRL,   $_[0]); }
sub text($)    { PlexTree->new->settstr(TEXT,   $_[0]); }
sub meta($)    { PlexTree->new->settstr(META,   $_[0]); }
sub hyper($)   { PlexTree->new->settstr(HYPER,  $_[0]); }
sub super($)   { PlexTree->new->settstr(SUPER,  $_[0]); }
sub ultra($)   { PlexTree->new->settstr(ULTRA,  $_[0]); }
sub para($)    { PlexTree->new->settstr(PARA,   $_[0]); }
sub trans($)   { PlexTree->new->settstr(TRANS,  $_[0]); }
sub binary($)  { PlexTree->new->settstr(BINARY, $_[0]); }
sub listpos($) {
    # todo: come up with a sortable variable-length encoding
    PlexTree->new->settstr(LISTPOS, pack("N", $_[0]));
}
sub tstring($$) {
    my ($tag, $s) = @_;
    die("PlexTree::tstring: invalid tag value")
	if $tag < MINTAG || $tag > MAXTAG;
    return PlexTree->new->settstr($_[0], $_[1]);
}

# Shorthand for converting a CRF-T string into a PlexTreeMem object
sub c {
    if (wantarray) {
	return map { text($_)->cd(ctrl 'textdec')->newroot } @_;
    } else {
	return text($_[0])->raw->cd(ctrl 'textdec')->cooked->newroot;
    }
}


package PlexTreeMem;

# In-memory representation of mutable compounds

use strict;
use bytes;
no locale;
require Scalar::Util;  # for refaddr and blessed
require Encode;

our @ISA = ('PlexTree');

# Internal representation:
#
# The PlexTreeMem object $self is an array [$parent, $kref, $nosub,
# $env, $node] that represents a current node position ("cursor")
# within a compound. The first four elements are as in the PlexTree
# superclass. The fifth node is
#
# $node = $self->[4]   a reference to the hash table that represents
#                      the current node
#
# Each node is represented by a node hash table. The hash keys are
# the CRF-S encoded visible keys, the corresponding values are
# references to the hash tables representing the value nodes.
#
# In the absence of a node hash table (undef), the corresponding node
# is interpreted to be an empty string with tag 1 (empty control string).
#
# The string is stored in the node hash table under the key HSTRING,
# where an undefined or missing hash value is interpreted as an empty
# string. The tag is stored as an integer (0-15) under the key HTAG,
# where an undefined or missing hash value is interpreted as tag 0
# (control string) if no key HSTRING is present, and as tag 1 (text
# string) otherwise.
# 
# The list elements are stored in the node hash table under the key
# HLIST, which references an array that in turn references the
# individual node hash tables representing the list elements.
#
# If the node hash table has a key HKEYS, then its value is a
# reference to a sorted array of all CRF-S encoded visible keys. Such
# an entry must be deleted each time the set of visible keys of a node
# changes, and can then be recreated by calling _sortkeys().
#
# The $self->[1] is merely a cache of the key or list position. It has
# to be verified before each use via the corresponding parent data
# structure, because it may have changed due to editing since the last cd()
# into this node.

# these special keys must not be elements of the set of possible CRF-S strings
use constant HSTRING => "STR";
use constant HTAG    => "TAG";
use constant HLIST   => "LST";
use constant HKEYS   => "KYS";

# Create a new PlexTreeMem object, that is a cursor pointing to the root
# of a new empty compound.
#
# Normally, $kref and $parent are left undefined. These parameters
# exist only for the benefit of filters, who may want to define
# a PlexTreeMem object, in which the new "root" node created here
# has actually a parent, such that a normal up() can be used to
# leave a temporary PlexTreeMem object that was generated by a filter.
sub new {
    my ($this, $parent, $kref) = @_;
    my $class = ref($this) || $this;
    if (defined $parent) {
	return bless [ $parent, $kref, $parent->[2], $parent->[3], { } ]
	    => $class;
    } else {
	# define initial hash here (to define unique node id for nid())
	return bless [ undef, undef, { }, undef, { } ] => $class;
    }
}

=item cid()

Return a unique reference integer for this compound.

=cut
sub cid() {
    my ($self) = @_;
    return $self->top->nid;
}

=item nid()

Return a unique reference integer for this cursor position in this compound.

=cut
sub nid() {
    my ($self) = @_;
    my $node = $self->[4];
    $node = $self->_createhash unless defined $node;
    return Scalar::Util::refaddr($node);
}

=item I<isonpathto(CURSOR)>

Returns 1 if the current cursor position is located on the path to
CURSOR, and 0 otherwise. Returns 1 if the current cursor position and
CURSOR are identical.

=cut
sub isonpathto {
    my ($self, $other) = @_;

    while (defined $other) {
	return 1 if ($self->nid eq $other->nid);
	$other = $other->parent;
    }
    return 0;
}

=item I<nextonpathto(CURSOR)>

If the current cursor position is located on the path to CURSOR, then
return that of its child nodes that is next on that path, otherwise
return undef. Returns undef if the current cursor position and CURSOR
are identical.

=cut
sub nextonpathto {
    my ($self, $other) = @_;

    while (defined $other) {
	my $parent = $other->parent;
	return $other if (defined $parent && $self->nid eq $parent->nid);
	$other = $parent;
    }
    return;
}

=item pos()

Return the current list position if the current node is a list
element, and undef not.

=cut
sub pos {
    my ($self) = @_;
    my $pos = $self->[1];
    my $node = $self->[4];

    return undef unless defined $self->[0] && defined $pos; # this is root
    return undef if ref $pos; # this is not a list element
    my $parentlist = $self->[0]->[4]->{HLIST()};
    # check whether $pos still represents this node's list position
    if ($parentlist->[$pos] == $node) {
	return $pos;
    }
    # if not, perform linear search through parent array.
    $pos = 0;
    foreach my $l (@$parentlist) {
	if ($l == $node) {
	    $self->[1] = $pos;
	    return $pos;
	}
	$pos++;
    }
    die("Cannot find list position!\n");
}

# call this internal helper subroutine if (and only if) the current
# node at which the cursor is positioned is not yet represented by a
# hash table and you need one, return reference to the new hash
sub _createhash {
    my ($self) = @_;
    my $node;
    my $notroot = defined $self->[0] && defined $self->[1];
    die("hash already exists") if defined $self->[4]; # assertion
    # has someone else already created a hash?
    if ($notroot) {
	if (ref($self->[1])) {
	    # existing hash for key value?
	    $node = $self->[0]->[4]->{${$self->[1]}};
	} else {
	    # existing hash for list element?
	    $node = $self->[0]->[4]->{HLIST()}->[$self->pos];
	}
	return $self->[4] = $node if $node;
    }
    # if not, create hash table for node
    $node = $self->[4] = {};
    # if this is not the root, update hash entry in parent node 
    if ($notroot) {
	if (ref($self->[1])) {
	    # create hash for key value
	    $self->[0]->[4]->{${$self->[1]}} = $node;
	} else {
	    # create hash for list element
	    $self->[0]->[4]->{HLIST()}->[$self->pos] = $node;
	}
    }
    return $node;
}

=item str()

=item I<str(OFFSET)>

=item I<str(OFFSET, LENGTH)>

Returns the string associated with the current node. If OFFSET is
defined, that many bytes at the start of the string will be skipped.
If LEN is defined, then only up to that many bytes will be returned.
The returned value will be a Perl binary string.

=cut
sub str {
    my $node = $_[0]->[4];  # current node from cursor

    return '' unless defined $node && exists $node->{HSTRING()};
    return $node->{HSTRING()}                  if (@_ == 1);
    return substr($node->{HSTRING()}, $_[1])   if (@_ == 2);
    return substr($node->{HSTRING()}, $_[1], $_[2]);
}

=item ustr()

=item I<ustr(OFFSET)>

=item I<ustr(OFFSET, LENGTH)>

Like str(), but returns a Unicode (UTF-8) Perl string for tag values < 8,
and a Perl byte string otherwise.

=cut
sub ustr {
    my $s = str(@_);
    if ($_[0]->tag < 8) {
	Encode::_utf8_on($s);
      } else {
        Encode::_utf8_off($s);
    }
    return $s;
}

=item str_ctrl()

=item str_text()

=item str_meta()

=item str_hyper()

Like str(), but returns undef if the tag is not CTRL (0), TEXT (1),
META (2), HYPER (3), etc., respectively.

=cut
sub str_ctrl { return unless defined $_[0] && $_[0]->tag == PlexTree::CTRL;  str(@_); }
sub str_text { return unless defined $_[0] && $_[0]->tag == PlexTree::TEXT;  str(@_); }
sub str_meta { return unless defined $_[0] && $_[0]->tag == PlexTree::META;  str(@_); }
sub str_hyper{ return unless defined $_[0] && $_[0]->tag == PlexTree::HYPER; str(@_); }
sub str_super{ return unless defined $_[0] && $_[0]->tag == PlexTree::SUPER; str(@_); }
sub str_ultra{ return unless defined $_[0] && $_[0]->tag == PlexTree::ULTRA; str(@_); }
sub str_para { return unless defined $_[0] && $_[0]->tag == PlexTree::PARA;  str(@_); }
sub str_trans{ return unless defined $_[0] && $_[0]->tag == PlexTree::TRANS; str(@_); }

=item ustr_ctrl()

=item ustr_text()

=item ustr_meta()

=item ustr_hyper()

Like ustr(), but returns undef if the tag is not CTRL (0), TEXT (1),
META (2), HYPER (3), etc., respectively.

=cut
sub ustr_ctrl { return unless defined $_[0] && $_[0]->tag == PlexTree::CTRL;  ustr(@_); }
sub ustr_text { return unless defined $_[0] && $_[0]->tag == PlexTree::TEXT;  ustr(@_); }
sub ustr_meta { return unless defined $_[0] && $_[0]->tag == PlexTree::META;  ustr(@_); }
sub ustr_hyper{ return unless defined $_[0] && $_[0]->tag == PlexTree::HYPER; ustr(@_); }
sub ustr_super{ return unless defined $_[0] && $_[0]->tag == PlexTree::SUPER; ustr(@_); }
sub ustr_ultra{ return unless defined $_[0] && $_[0]->tag == PlexTree::ULTRA; ustr(@_); }
sub ustr_para { return unless defined $_[0] && $_[0]->tag == PlexTree::PARA;  ustr(@_); }
sub ustr_trans{ return unless defined $_[0] && $_[0]->tag == PlexTree::TRANS; ustr(@_); }

=item len()

Returns the string length of the current node.

=cut
sub len {
    my ($self) = @_;
    my $node = $self->[4];  # current node from cursor

    return 0 unless defined $node && exists $node->{HSTRING()};
    return length($node->{HSTRING()});
}

=item tag()

Returns the tag associated with the current node, which is an integer
value in the range 0 to 15.

=cut
sub tag {
    my ($self) = @_;
    my $node = $self->[4];  # current node from cursor

    return PlexTree::CTRL unless defined $node;
    if (exists $node->{HTAG()}) {
	return $node->{HTAG()};
    } else {
	return exists $node->{HSTRING()} ? 1 : 0;
    }
}

=item dirlen()

Returns the number of visible keys of the current node.

=cut
sub dirlen {
    my $self = shift;
    my $node = $self->[4];  # current node from cursor
    
    return 0 unless defined $node;
    _sortkeys($node);
    return scalar(@{$node->{HKEYS()}});
}

=item listlen()

Returns the number of list elements of the current node.

=cut
sub listlen {
    my $self = shift;
    my $node = $self->[4];  # current node from cursor

    return 0 unless defined $node;
    return 0 unless exists $node->{HLIST()};
    return scalar(@{$node->{HLIST()}});
}

=back

The following methods are available for the mutable in-memory PlexTree
objects that are generated by PlexTree::new():

=over 4

=item I<settag(INTEGER)>

Set the tag value, which is an integer, such as PlexTree::CTRL = 0,
PlexTree::TEXT = 1, PlexTree::META = 2, etc. (Tag value must be within
the range PlexTree::MINTAG .. PlexTree::MAXTAG.)

=cut
sub settag {
    my ($self, $tag) = @_;
    my $node = $self->[4];  # current node from cursor

    if (!defined $node) {
	if ($tag == PlexTree::CTRL) {
	    return $self;
	} else {
	    $node = $self->_createhash;
	    $node->{HTAG()} = $tag;
	}
    } else {
	if ($tag == (exists $node->{HSTRING()} ? PlexTree::TEXT : PlexTree::CTRL)) {
	    delete $node->{HTAG()};
	} else {
	    $tag = int($tag);
	    die("PlexTree->settag($tag): invalid tag value")
		unless $tag >= PlexTree::MINTAG && $tag <= PlexTree::MAXTAG;
	    $node->{HTAG()} = $tag;
	}
    }
    return $self;
}

=item I<setstr(STRING)>

=item I<setstr(STRING, POS)>

=item I<setstr(STRING, POS, LEN)>

Sets the string content, or substring thereof. Parameters POS and LEN
behave the same as with the Perl function substr.
If the previous value was an empty string with tag 0 (= control
string), then this function will implicitely change the tag to 1 (=
plain text). Therefore, when setting both string and tag, set the tag
after the string, or use settset() to set both at the same time.

=cut
sub setstr {
    my ($self, $s, $pos, $len) = @_;
    my $node = $self->[4];  # current node from cursor

    Encode::_utf8_off($s);   # keep UTF-8 strings out
    if (!defined $node) {
	# create hash table for current node
	$node = $self->_createhash;
    }
    $node->{HSTRING()} = $s unless defined $pos || defined $len;
    if (defined $pos) {
	die("invalid position") if $pos < 0;
	die("invalid length")   if defined $len && $len < 0;
    } else {
	$pos = 0;
    }
    if (defined $len) { 
	substr($node->{HSTRING()}, $pos, $len) = $s;
    } else {
	substr($node->{HSTRING()}, $pos) = $s;
    }
    return $self;
}

=item I<settstr(TAG, STR)>

Set the tag value of the current node to TAG and its byte string to STR.

=cut
sub settstr {
    my ($self, $tag, $s) = @_;
    my $node = $self->[4];  # current node from cursor

    Encode::_utf8_off($s);   # keep UTF-8 strings out
    if (!defined $node) {
	return $self unless length $s > 0 || $tag != 0;
	# create hash table for current node
	$node = $self->_createhash;
    }
    if (length $s) {
	$node->{HSTRING()} = $s;
    } else {
	delete $node->{HSTRING()}
    }
    if ($tag == exists $node->{HSTRING()}) {
	delete $node->{HTAG()};
    } else {
	$node->{HTAG()} = $tag;
    }
    return $self;
}

=item I<appstr(STR)>

Append STR to the end of the byte string of the current node.

=cut
sub appstr {
    my ($self, $s) = @_;
    my $node = $self->[4];  # current node from cursor

    if (defined $node) {
	$node->{HSTRING()} .= $s;
    } else {
	return $self unless length($s) > 0;
	$node = $self->_createhash;
	$node->{HSTRING()} = $s;
    }
    return $self;
}

# The PlexTreeMem data structure supports auxiliary keys. These do not
# form part of the compound data structure and their values will be
# ignored when serializing or comparing compounds. They may be used by
# application-specific subclasses of PlexTreeMem or by filters, which
# may find it useful to hold arbitrary Perl data for internal
# purposes. A typical application would be a cached access index. Each
# key belongs to a "domain", which is usually the name of the package
# that has added they key. The key name should be restricted to
# [A-Za-z0-9-].

sub aux {
    my ($self, $key, $value, $domain) = @_;
    my $node = $self->[4];  # current node from cursor
    $domain = ref $self unless defined $domain;
    return $node->{"~$domain~$key"} if defined $node;
}

sub setaux {
    my ($self, $key, $value, $domain) = @_;
    my $node = $self->[4];  # current node from cursor
    if (!defined $node) {
	# create hash table for current node
	$node = $self->_createhash;
    }
    $domain = ref $self unless defined $domain;
    $node->{"~$domain~$key"} = $value;
}

sub deleteaux {
    my ($self, $key, $domain) = @_;
    my $node = $self->[4];  # current node from cursor
    return unless defined $node;
    $domain = ref $self unless defined $domain;
    if (defined $key) {
	delete $node->{"~$domain~$key"};
    } else {
	# delete all keys in that domain
	for $key (keys %{$node}) {
	    delete $node->{"~$domain~$key"} if $key =~ /^~$domain~/;
	}
    }
}

# Add one or more new directory entries. Parameter @kv is a list of
# key/value pairs. A directory entry is added for each provided key,
# unless that key already exists. If a value is provided for a key, that
# value is stored accordingly. The function returns $self, unless
# @kv contains only a single key, in which case a cursor to its newly
# created value node is returned instead.
sub addkey {
    my ($self, @kv) = @_;

    my $key = shift @kv;
    my $new = $self;
    if (ref($key) eq 'ARRAY') {
	# handle array of keys as descent path
	foreach my $k (@$key) {
	    $new = $new->addkey($k);
	}
    } else {
	my $node = $self->[4];  # current node from cursor
	my $s = PlexTree::crfs($key);
	
	$node = $self->_createhash unless defined $node;
	# add new key and value
	if (!exists $node->{$s}) {
	    # create a new node
	    $node->{$s} = undef;
	    delete $node->{HKEYS()};  # invalidate sorted list of visible keys
	}
	$new = bless([ $self, \$s, $self->[2], $self->[3], $node->{$s} ]
		     => ref($self));
    }

    # optionally assign a value and process further keys
    if (@kv) {
	my $value = shift @kv;
	if (defined $value) {
	    if (ref $value eq '') {
		# the key we got is a text string -> convert to compound
		$new->move(PlexTree::c($value));
	    } else {
		$new->copyfrom($value);
	    }
	}
	return $self->addkey(@kv) if @kv;
	return $self;
    }

    return $new;
}


=item I<setatt(KEY, VALUE, ...)>

This is a simplified version of I<addkey()> where keys and values are
always normal text strings (tag 1). This form is more convenient for
the common case of SGML-style attribute/value pairs. The parameters
are a list alternating key and value strings pairs and these pairs
will be set in the current compound as such. The return value is
always the current compound.

=cut
sub setatt {
    my ($self, @kv) = @_;

    my $node = $self->[4];  # current node from cursor
    $node = $self->_createhash unless defined $node;
    delete $node->{HKEYS()};  # invalidate sorted list of visible keys
    my $key;
    my $value;
    while ($key = shift @kv, $value = shift @kv, defined $key) {
	my $s = PlexTree::crfs($key);
	if (defined $value) {
	    $node->{$s} = { HSTRING() => $value };
	} else {
	    $node->{$s} = { }
	}
    }

    return $self;
}

=item selftokey()

Take everything from the current position downwards, add it as a key
to itself, then erase everything else from the current position
downwards, and return a new cursor pointing at the value of its only
key

=cut
sub selftokey {
    my ($self) = @_;
    my $node = $self->[4];  # current node from cursor
    my $s = $self->crfs;
    
    $self->clear;
    # add new key
    $node->{$s} = undef;
    # return new cursor to its value
    return bless [ $self, \$s, $self->[2], $self->[3], $node->{$s} ]
	=> ref($self);
}

=item I<cut()>

Remove the current list element or key/value pair (where the current
node is the value of that pair) and return the resulting parent-free
compound.

=cut
sub cut {
    my ($self) = @_;

    # disconnect $self from its parent
    if (defined $self->[0] && defined $self->[1]) {
	if (ref($self->[1])) {
	    # erase value associated with $self->key in parent hash
	    $self->[0]->[4]->{${$self->[1]}} = undef;
	} else {
	    # erase value associated with $self->pos in parent list
	    CORE::splice(@{$self->[0]->[4]->{HLIST()}}, $self->pos, 1);
	}
    }
    $self->[0] = $self->[1] = undef;
    return $self;
}

=item I<move(SRC)>

Moves an entire subcompound from the provided node SRC to the current
node, emptying in the process both the previous content of the
currenbt node and the remaining content of SRC.

=cut
sub move {
    my ($self, $src) = @_;

    die("You can only move from PlexTreeMem objects, not from " . ref $src)
	unless $src->isa('PlexTreeMem');

    # disconnect $src from its parent
    $src->cut;
    # move $src
    $self->[4] = $src->[4];
    # reconnect $self->parent to new node
    if (defined $self->[0] && defined $self->[1]) {
	if (ref($self->[1])) {
	    # update key value
	    $self->[0]->[4]->{${$self->[1]}} = $self->[4];
	} else {
	    # update list element
	    $self->[0]->[4]->{HLIST()}->[$self->[1]] = $self->[4];
	}
    }

    return $self;
}

=item I<movekey(SRC, KEY)>

Moves a key/value pair identified by KEY from the SRC node to the
current node.

=cut
sub movekey {
    my ($self, $src, $key) = @_; 
    die("You can only move from PlexTreeMem objects, not from " . ref $src)
	unless $src->isa('PlexTreeMem');
    my $ks = $key->crfs;
    return unless defined $src->[4] && exists $src->[4]->{$ks};
    my $value = $src->[4]->{$ks};
    my $node = $self->[4];  # current node from cursor
    $node = $self->_createhash unless defined $node;
    # link value from destination hash table
    $node->{$ks} = $value;
    # delete key and value from source hash table
    delete $src->[4]->{$ks};
    return $self;
}

=item I<movedir(SRC)>

Moves all key/value pairs from the SRC node to the current node.

=cut
sub movedir {
    my ($self, $src) = @_;
    foreach my $k ($src->keys) {
	$self->movekey($src, $k);
    }
}


=item I<movelist(SRC)>

Moves the sublist from the provided node SRC to the current node,
replacing the current node's list.

=cut
sub movelist {
    my ($self, $src) = @_;

    $self->splice(); # delete existing list
    foreach my $l ($src->list) {
	$self->append->move($l)
    }

    return $self;
}

=item flatten()

Remove the current node (which must be a list element) and its
key-value elements from the tree and inserts its list elements in its
place.

=cut
sub flatten {
    my ($self) = @_;
    $self->insert(map { $_->cut } $self->list);
    $self->cut;
}

=item I<deletekey(KEY)>

Deletes a key and associated value

=cut
sub deletekey {
    my ($self, $key) = @_; 
    my $node = $self->[4];  # current node from cursor
    return unless defined $node;
    delete $node->{$key->crfs};
    return $self;
}

# generate internal sorted list of visible keys
sub _sortkeys {
    my ($node) = @_;
    return if exists $node->{HKEYS()};
    my @l = sort keys %$node;
    # remove the non-compound private hash keys
    pop @l while @l && $l[$#l] =~ /^[A-Z]/;
    $node->{HKEYS()} = \@l;
}

=item I<splice(OFFSET, LEN, LIST)>

Removes and or inserts nodes in the sublist of the current node by
replacing the LEN list elements after the first OFFSET ones with
copies of those provided in LIST, if any. The list grows or shrinks as
necessary. If OFFSET < 0, it starts that far from the end of the list.
If the integer OFFSET is missing or undefined, append LIST at the end
of the list. If the integer LEN is undefined or missing, then
interpret it as "until the end of the list". If OFFSET or LEN go
beyond the end of the list, they are interpreted as refering to the
end of the list. When called in a list context, this function will
return the list of removed nodes.

=cut
sub splice {
   my ($self, @values) = @_; 
   my $offset;
   my $length;
   use Storable;
   # get position parameters
   $offset = shift @values if (@values && !ref $values[0]);
   $length = shift @values if (@values && !ref $values[0]);
   # normalize position parameters
   my $len = $self->listlen;
   if (defined $offset) {
       if ($offset > $len) {
	   $offset = $len;
       } elsif ($offset < 0) {
	   $offset = $len + $offset;
       }
   } else {
       $offset = $len;
   }
   if (defined $length) {
       if ($length + $offset > $len) {
	   $length = $len - $offset;
       } elsif ($length < 0) {
	   die("Negative length $length in PlexTreeMem::splice()\n");
       }
   } else {
       $length = $len - $offset;
   }
   # prepare list access
   my $node = $self->[4];  # current node from cursor
   $node = $self->_createhash unless defined $node;
   $node->{HLIST()} = [] unless exists $node->{HLIST()};
   # modify list
   my @removed = CORE::splice(@{$node->{HLIST()}}, $offset, $length,
			      map { Storable::dclone($_->[4]); } @values);
   return(map { bless [ undef, undef, undef, undef, $_ ] => ref($self)}
	  @removed) if wantarray;
   return undef;
}

=item I<append(LIST)>

Append one or more new list elements at the end of the current node's
list. If LIST is empty, then a single new node will be appended, which
will have an empty control string, and the return value will be the
cursor of this empty new node. If LIST is not empty, then a copy of
each defined LIST element will be appended, undef LIST elements will
be skipped, and the return value will be the cursor of the current
node. LIST elements must be PlexTree objects.

=cut
sub append {
    my ($self, @values) = @_;

    if (@values) {
	for my $value (@values) {
	    next unless defined $value;
	    if (ref $value eq '') {
		# the key we got is a text string -> convert to compound
		$self->append->move(PlexTree::c($value));
	    } else {
		$self->append->copyfrom($value);
	    }
	}
	return $self;
    } else {
	my $node = $self->[4];  # current node from cursor
	$node = $self->_createhash unless defined $node;
	my $newnode = { };
	if (exists $node->{HLIST()}) {
	    push @{$node->{HLIST()}}, $newnode;
	} else {
	    $node->{HLIST()} = [ $newnode ];
	}
	my $new = bless [ $self, scalar(@{$node->{HLIST()}})-1,
			  $self->[2], $self->[3], $newnode ]
			      => ref($self);
	return $new;
    }
}

=item I<insert(LIST)>

If the current node is a list element, then this method will insert a
new list element right before the current node. If the current node is
not a list element, an exception will be raised. If LIST is empty,
then a single new node will be inserted, which will have an empty
control string, and the return value will be the cursor of this empty
new node. If LIST is not empty, then a copy of each defined LIST
element will be appended, undef LIST elements will be skipped, and the
return value will be the cursor of the current node. LIST elements
must be PlexTree objects.

=cut
sub insert {
    my ($self, @values) = @_;

    if (@values) {
	for my $value (@values) {
	    next unless defined $value;
	    if (ref $value eq '') {
		# the key we got is a text string -> convert to compound
		$self->insert->move(PlexTree::c($value));
	    } else {
		$self->insert->copyfrom($value);
	    }
	}
	return $self;
    } else {
	my $pos = $self->pos;
	die("Insert called for a node that is not a list element!\n")
	    unless defined $pos;
	my $parentlist = $self->[0]->[4]->{HLIST()};
	my $newnode = { };
	CORE::splice(@$parentlist, $pos, 0, $newnode);
	my $new = bless [ $self->[0], $pos,
			  $self->[2], $self->[3], $newnode ]
			      => ref($self);
	$self->[1]++; # update this cursor's list position
	return $new;
    }
}

# remove everything from the current cursor position downwards
# (empty string, tag 0), but don't remove the hash
sub clear {
    my $self = shift;
    my $node = $self->[4];  # current node from cursor

    return $self unless defined $node;
    %{$node} = ();
    return $self;
}

# remove every list element from the current cursor position downwards
sub clear_list {
    my $self = shift;
    my $node = $self->[4];  # current node from cursor

    return $self unless defined $node;
    delete $node->{HLIST()};
    return $self;
}

# Dump the entire datastructure to STDERR and return a
# pointer to self (such that debug can be callen in ...->...->... chains)
sub debug {
    my ($self, $label, $options) = @_;
    use Data::Dumper;
    my $d = Data::Dumper->new([$self]);
    $d->Useqq(1);
    $d->Maxdepth($options->{'maxdepth'}) if (exists $options->{'maxdepth'});
    $label = (defined $label) ? ": $label" : '';
    print "\n\n====== DEBUG START$label ======\n";
    print $d->Dump;
    print "\n======= DEBUG END$label =======\n\n";
    return $self;
}

# tree navigation

# return an array of PlexTree objects, one for each visible key at
# the current cursor position
sub keys {
    my ($self) = @_;
    my $node = $self->[4];  # current node from cursor
    return () unless defined $node;
    _sortkeys($node);
    return () unless @{$node->{HKEYS()}};
    return map { PlexTree->new->copyfrom_crfs($_) } (@{$node->{HKEYS()}});
}

# return an array of PlexTree objects, one for each list element at
# the current cursor position
sub list_r {
    my ($self) = @_;
    my $node = $self->[4];  # current node from cursor
    my $i = 0;
    return () unless defined $node;
    return () unless $node->{HLIST()};
    return map { bless [ $self, $i++, $self->[2], $self->[3], $_ ]
		     => ref $self }
               (@{$node->{HLIST()}});
}

# descend into dictionary entry
sub cd_r {
    my ($self, $key) = @_;
    my $node = $self->[4];  # current node from cursor
    my $ks = $key->crfs;

    return undef unless exists $node->{$ks};
    return bless [ $self, \$ks, $self->[2], $self->[3], $node->{$ks}]
	=> ref($self);
}

# descend into list entry
# TODO: much of that functionality should probably move to cl().
sub cl_r {
    my ($self, $pos) = @_;
    my $node = $self->[4];  # current node from cursor
    
    $pos = int($pos);       # make sure we have a proper integer value
    if ($pos >= 0) {
	# descend into a regular list element
	return undef unless defined $node &&
	    exists $node->{HLIST()} && exists $node->{HLIST()}->[$pos];
	return bless [ $self, $pos, $self->[2], $self->[3],
		       $node->{HLIST()}->[$pos] ] => ref($self);
    } else {
	# virtual list of sorted keys and values
	use integer;
	my $dl = $self->dirlen;
	my $i = $dl + ($pos >> 1);
	return undef if $i >= $dl;
	my $ks = $node->{HKEYS()}->[$i];  # the CRF-S encoded key
	if ($pos & 1) {
	    # descend into the value
	    return bless [ $self, $pos, $self->[2], $self->[3], $node->{$ks} ]
		=> ref($self);
	} else {
	    # descend into the key
	    return PlexTreeMem->new($self, $pos)->copyfrom_crfs($ks);
	}
    }
}

# Some annotation filters

# A cd(ctrl('self')) does nothing other than activating any
# substitution filters that might be applicable to the
# current position. In particular, it does not change depth.
PlexTree::register_augmentation_filter
    ('self',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 return $parent;
     });

# Deactivate all substitution filters in any child nodes
PlexTree::register_augmentation_filter
    ('raw',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 return $parent->raw;
     });

# Shows the number of up() operations possible from current position
PlexTree::register_augmentation_filter
    ('depth',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $tmp = PlexTreeMem->new($parent, $kref);
	 $tmp->setstr($parent->depth);
	 return $tmp;
     });

# Shows the number of up() operations possible from current position
PlexTree::register_augmentation_filter
    ('printpath',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $tmp = PlexTreeMem->new($parent, $kref);
	 $tmp->setstr($parent->print_path);
	 return $tmp;
     });

# list set
PlexTree::register_augmentation_filter
    ('ls',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $tmp = PlexTreeMem->new($parent, $kref);
	 foreach my $k ($parent->keys) {
	     $tmp->addkey($k);
	 }
	 return $tmp;
     });

# equality test
PlexTree::register_augmentation_filter
    ('eq',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $input = $arg->cl(0);
	 if (defined $input && $parent->cmp($input) == 0) {
	     return PlexTreeMem->new($parent, $kref)->setstr('1');
	 }
	 return PlexTreeMem->new($parent, $kref);
     });

# symbolic link from root
PlexTree::register_substitution_filter
    ('sr',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $target = $parent->top;	
	 foreach my $k ($arg->list) {
	     $target = $target->cd($k);
	     die("No key " . $k->print({oneline=>1}) . " exists\n")
		 unless defined $target;
	 }
	 return $target;
     });

# find a list element by string content (and attribute(s))
PlexTree::register_augmentation_filter
    ('l',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $match = $arg->cl(0);
	 return undef unless defined $match;
	 return $parent->lfind($match, $arg->getl(0), $arg->get('maxdepth'));
     });

# find a direct-child list element by string content (and attribute(s))
PlexTree::register_augmentation_filter
    ('l1',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $match = $arg->cl(0);
	 return undef unless defined $match;
	 return $parent->lfind($match, $arg->getl(0), 1);
     });

# test
PlexTree::register_augmentation_filter
    ('test',
     sub {
	 my ($parent, $kref, $arg) = @_;
	 my $tmp = PlexTreeMem->new($parent, $kref);
	 $tmp->setstr($parent->ispath ? 1 : 0);
	 return $tmp;
     });

1;

=back

[... TO BE COMPLETED ...]

=head1 FUNCTIONS

Apart from the PlexTree class and subclasses and their methods, this
package also defines a number of static functions [... TO BE COMPLETED ...]

=head1 AUTHOR

Both the PlexTree architecture and this Perl package that implements
it were developed by Markus Kuhn <http://www.cl.cam.ac.uk/~mgk25/>.
