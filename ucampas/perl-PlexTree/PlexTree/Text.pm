=head1 NAME

PlexTree::Text - plain-text representation of compounds

=cut

package PlexTree::Text;

use strict;
use bytes;
no locale;
use Carp;
use PlexTree;

########################################################################
# Pretty printer
########################################################################

PlexTree::register_augmentation_filter('textenc', \&af_textenc);

sub render($$$$$);

# Provide CRF-T plain-text serialization
# Options (add as elements to hash %$opt):
#
#   oneline       no linefeeds, render as compact as possible
#   noempty       do not skip implicit empty control strings '.'
#   nopath        avoid the path notation and use parenthesis for all sets
#   implicitlist  drop no outer-level list parenthesis

sub af_textenc {
    my ($parent, $kref, $arg) = @_;
    my $tmp = PlexTreeMem->new($parent, $kref);
    my $opt = $arg->options(1);
    
    $opt->{tab} = '  ' unless defined $opt->{tab};
    # call pretty-printer and write result to returned tree
    $tmp->setstr(render($parent, '', 1, 'T', $opt));
    return $tmp;
}

my %qesc = ( "\n" => 'n',
	     "\r" => 'r',
	     "\""  => '"',
	     "\'"  => "'",
	     "\\"  => "\\");
my %rqesc = reverse %qesc;

# Place quotes around a string and replace all bytes in $s that
# are quotes, backslashes, control characters, or invalid UTF-8
# sequences with suitable backslashed escape sequences.
sub quotetext {
    my ($s) = @_;
    my @r = ();
    my $e;
    my $quote = "'";
    $quote = '"' if $s =~ /\'/ > $s =~ /\"/;
    while (1) {
	if ($s =~ /\G(([^\x00-\x1f\"\'\\\x80-\xff]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3})+)/gc) {
	    push @r, $1;
	} elsif ($s =~ /\G([\"\'\\])/gc) {
	    if ($1 eq $quote || $1 eq "\\") {
		push @r, "\\";
	    }
	    push @r, $1;
	} else {
	    last unless $s =~ /\G(.)/sgc;
	    push @r, defined($e = $qesc{$1}) ? "\\$e" :
		sprintf("\\x%02x", ord($1));
	};
    }

    return join('', $quote, @r, $quote);
}

# undo quotetext() escaping
sub unquotetext {
    my ($s) = @_;
    my @r = ();
    
    die("quotation mark expected\n") unless $$s =~ /\G([\'\"])/gc;
    my $openq = $1;
    while (1) {
	if ($$s =~ /\G([^\'\"\\]+)/gc) {
	    push @r, $1;
	} elsif ($$s =~ /\G([\'\"])/gc) {
	    return join('', @r) if $1 eq $openq;
	    push @r, $1;
	} elsif ($$s =~ /\G\\[xX]([0-9a-fA-F]{2})/gc) {
	    push @r, chr(hex($1));
	} elsif ($$s =~ /\G\\(.)/gc) {
	    if (exists $rqesc{$1}) {
		push @r, $rqesc{$1};
	    } else {
		die("Encountered unexpected backslash sequence '\\$1'\n");
	    }
	} else {
	    die("Unexpected end encountered in quoted string\n")
	}
    }
}

# $context: 'S' this is already a set element (e.g., because preceding /)
sub render($$$$$) {
    my ($self, $indent, $permitempty, $context, $opt) = @_;
    my $r;
    
    # handle paths
    if (!$opt->{nopath} && $self->ispath) {
	my $key   = $self->cl(-2); # the sole key
	my $value = $self->cl(-1); # its value
	# descend into the sole key
	$r .= render($key, $indent, 0, '', $opt);
	# last empty-valued key after / needs no trailing '/' or =
	return $r if ($value->isempty && $context eq 'S');
	# use '/' only to separate keys, otherwise use '='
	$r .= (!$opt->{nopath} && $value->ispath) ? '/' : '=';
	# descend into its value
	$r .= render($value, $indent, 1, '', $opt);
	return $r;
    }

    my $t = $self->tag;
    my $s = $self->str;
    my $sl = $self->dirlen;
    my $ll = $self->listlen;

    # render tag & string
    if (($permitempty || $sl > 0 || $ll > 0) &&
	$t == CTRL && $s eq '' && !$opt->{noempty}) {
	$r = $s;
    } elsif ($t == TEXT) {
	if ($s =~ /^[a-zA-Z0-9_][a-zA-Z0-9_:\.-]*\z/) {
	    $r = $s;
	} else {
	    $r = quotetext($s);
	}
    } elsif ($t == CTRL  && $s =~ /^(?:[a-zA-Z0-9_][a-zA-Z0-9_:\.-]*)\z/) {
	$r = '.' . $s;
    } elsif ($t == META  && $s =~ /^(?:[a-zA-Z0-9_][a-zA-Z0-9_:\.-]*)\z/) {
	$r = '*' . $s;
    } elsif ($t == HYPER && $s =~ /^(?:[a-zA-Z0-9_][a-zA-Z0-9_:\.-]*)\z/) {
	$r = '+' . $s;
    } elsif ($t == BINARY) {
	$r = '<' . unpack('H*', $s). '>';
    } else {
	if ($t < 8) {
	    $r = $t . quotetext($s);
	} else {
	    $r = $t . '<' . unpack('H*', $s). '>';
	}
    }

    # render children
    
    my $oneline = defined $opt->{oneline} && $opt->{oneline} > 0 &&
	$self->depth >= $opt->{oneline} - 1;
    my $implicitlist = $opt->{implicitlist} && $context eq 'T' && $r eq '';
    my $subindent = ($oneline || $implicitlist) ? '' : ($indent . $opt->{tab});
    my $opendelim  = '(';
    my $closedelim = ')';
    my @r;

    if ($implicitlist) {
	$opendelim  = $closedelim = $indent = $subindent = '';
    }

    if ($self->listlen == 0 && !$implicitlist) {
	$opendelim  = '{';
	$closedelim = '}';
	# render key/value pairs
	for (my $i = -2 * $sl; $i < 0; $i += 2) {
	    my $key   = $self->cl($i);
	    my $value = $self->cl($i + 1);
	    my $rr;
	    # get the key
	    $rr = render($key, $subindent, 0, '', $opt);
	    if (!$value->isempty) {
		# get the corresponding value
		if (!$opt->{nopath} && $value->ispath) {
		    $rr .= '/' . render($value, $subindent, 1, 'S', $opt);
		} else {
		    $rr .= '=' . render($value, $subindent, 1, '', $opt);
		}
	    }
	    push @r, $rr;
	}
    } else {
	# render key/value pairs
	for (my $i = -2 * $sl; $i < 0; $i += 2) {
	    my $key   = $self->cl($i);
	    my $value = $self->cl($i + 1);
	    my $rr;
	    # get the key
	    $rr = render($key, $subindent, 0, '', $opt);
	    # get the corresponding value
	    if (!$opt->{nopath} && $value->ispath) {
		$rr .= '/' . render($value, $subindent, 1, 'S', $opt);
	    } else {
		$rr .= '=' . render($value, $subindent, 1, '', $opt);
	    }
	    push @r, $rr;
	}
	
	# render list elements
	for (my $i = 0; $i < $ll; $i++) {
	    my $rr;
	    $rr = render($self->cl($i), $subindent, 0, '', $opt);
	    push @r, $rr;
	}
    } 

    if (@r) {
	if ($oneline) {
	    $r .= $opendelim . join(', ', @r) . $closedelim;
	} else {
	    if ($implicitlist) {
		$r .=  join(",\n" . $subindent, @r);
	    } else {
		$r .= $opendelim . "\n" . $subindent .
		    join(",\n" . $subindent, @r) .
		    "\n" . $indent . $closedelim;
	    }
	    $r .= "\n" if $context eq 'T';
	}
    }
    
    return $r;
}


########################################################################
# Parser
########################################################################

# Where a tree of the form .textdec('...') is encountered, the text
# string '...' will be parsed as a CRF-T representation, and the result
# will replace the tree.
#
# Also, descending into a key .textdec('...') will lead into the result of
# decoding the current string as a CRF-T encoded compound.
#
# If a parsing error is encountered, an exception will be thrown (die),
# where the exception argument is a compound with an error message.
#
# If the supplied string ends prematurely (e.g., missing closing
# parenthesis), then this filter will attempt past the end of the provided
# argument string, from the initially provided strlen. This way, if
# the underlying tree is supplied by an interactive implementation, it
# gets an opportunity to prompt the user for another input
# line (effectively serving as a call-back function).

PlexTree::register_filter('textdec', \&textdec);

sub parse ($\$;$$);

sub textdec {
    my ($parent, $kref, $arg, $type) = @_;
    my $out = PlexTreeMem->new($parent, $kref);
    my $opt = $arg->options;
    $opt->{input} = $type eq 'a' ? $parent : $arg->cl(0);
    die("Missing argument\n") unless defined $opt->{input};
    my $s = $opt->{input}->str;  # string to be parsed
    # call recursive parser
    if (!defined eval {
	parse($out, $s, $opt, 0);
	die ("Unexpected '$1' after end of compound\n")
	    if $s =~ /\G(\S+)/;
    }) {
	# exception handling
	my $err = PlexTreeMem->new;
	chomp($@);
	$err->setstr($@);
	$err->addkey('input_suffix')->setstr(substr($s, pos($s)));
	# determine line and column position of error
	my $char = pos($s);
	my @l = split(/\n/, $s);
	my $line = 0;
	while ($char > 0 && defined $l[$line+1] &&
	       $char - (length($l[$line]) + 1) >= 0) {
	    $char -= length($l[$line++]) + 1;
	}
	$err->addkey('input')->setstr($s);
	$err->addkey('line')->setstr($l[$line]) if defined $l[$line];
	$err->addkey('errrow')->setstr($line + 1);
	$err->addkey('errcol')->setstr($char + 1);
	die($err);
    }
    
    return $out;
}


# This routine is called each time parse() reaches a point where
# simply reaching the end of the input string would constitute a
# syntax error. It skips whitepace (and UTF-8 BOMs) and then checks
# whether we have reached the end of $s. If so, it attempts to prompt
# the input source for more text. If the end of the text really has
# been reached, it aborts with an error message.
sub _noend {
    my ($s, $opt) = @_;
    while ($$s =~ /\G(\s|\x{ef}\x{bb}\x{bf})+/gc, $$s =~ /\G\z/) {
	my $c;
	$c = $opt->{input}->str($opt->{input}->len);
	die("Unexpected end encountered\n")
	    unless defined $c && length($c) > 0;
	my $oldpos = pos($$s);
	$$s .= $c;
	pos($$s) = $oldpos;
    }
}


# parse($c, \$s): Recursive parser function. Adds remaining
# text-encoded compound $$s to node $c.
# If the return value is 1, then the compound was followed by a / or =
# sign and was therefore stored as a key (with value recursively parsed
# as well). The return value is 0 otherwise.
sub parse ($\$;$$) {
    my ($out, $s, $opt, $permitempty) = @_;

    _noend($s, $opt) unless $permitempty;
    # parse the various tagged string notations
    if ($$s =~ /\G(\d*)<\s*/gc) {
	# binary string (hexadecimal representation)
	my $tag = BINARY;
	if ($1 ne '') {
	    $tag = int($1);
	    die("Tag >" . MAXTAG . " is not permitted\n") if $tag > MAXTAG;
	}
	$out->setstr('');
	until ($$s =~ /\G\s*>\s*/gc) {
	    _noend($s, $opt);
	    $$s =~ /\G\s+/gc;
	    while ($$s =~ /\G((?:[0-9a-fA-F]{2})+)\s*/gc) {
		$out->appstr(pack('H*', $1));
	    }
	    die("Expected two hexadecimal digits, but found '$1'\n")
		if $$s =~ /\G([^>][^>]?)/;
	}
	$out->settag($tag);
    } elsif ($$s =~ /\G(\d*|[\.\*\+])(?=[\'\"])/gc) {
	# quoted text string
	my $prefix = $1;
	$out->setstr(unquotetext($s));
	$$s =~ /\G\s+/gc;
	my $tag = TEXT;
	if    ($prefix eq '.') { $tag = CTRL; }
	elsif ($prefix eq '*') { $tag = META; }
	elsif ($prefix eq '+') { $tag = HYPER; }
	elsif ($prefix ne '') {
	    $tag = int($prefix);
	    die("Tag >" . MAXTAG . " is not permitted\n") if $tag > MAXTAG;
	}
	$out->settag($tag);
    } elsif ($$s =~ /\G([\.\*\+])((?:[a-zA-Z0-9_][a-zA-Z0-9_:\.-]*)?)\s*/gc ||
	     $$s =~            /\G()([a-zA-Z0-9_][a-zA-Z0-9_:\.-]*)\s*/gc) {
	# unquoted text string
	$out->setstr($2);
	my $tag = TEXT;
	if    ($1 eq '.') { $tag = CTRL; }
	elsif ($1 eq '*') { $tag = META; }
	elsif ($1 eq '+') { $tag = HYPER; }
	$out->settag($tag);
    } elsif ($$s =~ /\G(?:\(|\{)/) {
	# default: empty control string
	$out->setstr('');
	$out->settag(CTRL);
    } elsif ($permitempty && $$s =~ /\G(?:\)|\}|,|$)/) {
	# default: empty control string
	$out->setstr('');
	$out->settag(CTRL);
    } else {
	$$s =~ /\G(\S*)/;
	die("Unexpected '" . $1 . "'\n");
    }
    
    if ($$s =~ /\G\(\s*/gc) {
	# parse children (list notation)
	_noend($s, $opt);
	if ($$s !~ /\G\)\s*/gc) {
	    while (1) {
		_noend($s, $opt);
		my $t = PlexTree->new;
		if (parse($t, $$s, $opt, 0)) {
		    # a key and everything below was already parsed
		    $out->movedir($t);
		} else {
		    # this was not a key, so append it to the list
		    $out->append->move($t);
		}
		_noend($s, $opt);
		if ($$s =~ /\G,?\s*\)\s*/gc) {
		    last;
		} elsif ($$s !~ /\G,\s*/gc) {
		    $$s =~ /\G(\S*)/;
		    die("Unexpected '" . $1 . "' (missing comma before?)\n");
		}
	    }
	}
    } elsif ($$s =~ /\G\{\s*/gc) {
	# parse children (set notation)
	_noend($s, $opt);
	if ($$s !~ /\G\}\s*/gc) {
	    while (1) {
		_noend($s, $opt);
		my $t = PlexTree->new;
		my $list = $$s =~ /\G-\s*/gc;
		_noend($s, $opt);
		my $key = parse($t, $$s, $opt, 0);
		if ($list) {
		    # force whatever was parsed to be a list element
		    $out->append->move($t);
		} elsif ($key) {
		    # a key and everything below was already parsed
		    $out->movedir($t);
		} else {
		    # interpret whatever was parsed as set element
		    $out->addkey($t);
		}
		_noend($s, $opt);
		if ($$s =~ /\G,?\s*\}\s*/gc) {
		    last;
		} elsif ($$s !~ /\G,\s*/gc) {
		    $$s =~ /\G(\S*)/;
		    die("Unexpected '" . $1 . "' (missing comma before?)\n");
		}
	    }
	}
    }

    if ($$s =~ /\G([=\/])\s*/gc) {
	my $separator = $1;
	# turn the compound that was just parsed into a key
	my $v = $out->selftokey;
	# then parse its value as well
	my $key = parse($v, $$s, $opt, 1);
	if (!$key && $separator eq '/') {
	    # if the value we just parsed was not already recognized
	    # as a key (which would have happened if it were followed
	    # by '/' or '=', and this value was preceeded by '/', then
	    # turn it nevertheless into a key, because '/' signifies
            # that both the compound before *and* after it are keys
	    $v->selftokey;
	}
	return 1;
    }

    return 0;
}

# Load a CRF-T file into a compound
sub load {
    my ($fn) = @_;
    my $p;
    my $c;
    my $f;

    open($f, '<:utf8', $fn) || die("Cannot open input file '$fn': $!\n"); 
    {
	local $/;
	$p = <$f>;
    }
    close $f;
 
    if (!defined eval {
        # parse input
        $c = text($p)->cd(ctrl('textdec'))->newroot;
    }) {
	die $@->print_error($fn) if $@->isa('PlexTree');
	die $@;
    }
    return $c;
}

1;
