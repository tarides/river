=head1 NAME

PlexTree::SGML - convert HTML/XML files into compounds and back

TODO: documentation

=cut

package PlexTree::SGML;

use strict;
use bytes;
no locale;
use Carp;
use PlexTree;

sub DEBUG () { 0 }   # change to 1 to activate debugging output

our %entities = (
  nbsp     => 0x00a0,
  iexcl    => 0x00a1,
  cent     => 0x00a2,
  pound    => 0x00a3,
  curren   => 0x00a4,
  yen      => 0x00a5,
  brvbar   => 0x00a6,
  sect     => 0x00a7,
  uml      => 0x00a8,
  copy     => 0x00a9,
  ordf     => 0x00aa,
  laquo    => 0x00ab,
  not      => 0x00ac,
  shy      => 0x00ad,
  reg      => 0x00ae,
  macr     => 0x00af,
  deg      => 0x00b0,
  plusmn   => 0x00b1,
  sup2     => 0x00b2,
  sup3     => 0x00b3,
  acute    => 0x00b4,
  micro    => 0x00b5,
  para     => 0x00b6,
  middot   => 0x00b7,
  cedil    => 0x00b8,
  sup1     => 0x00b9,
  ordm     => 0x00ba,
  raquo    => 0x00bb,
  frac14   => 0x00bc,
  frac12   => 0x00bd,
  frac34   => 0x00be,
  iquest   => 0x00bf,
  Agrave   => 0x00c0,
  Aacute   => 0x00c1,
  Acirc    => 0x00c2,
  Atilde   => 0x00c3,
  Auml     => 0x00c4,
  Aring    => 0x00c5,
  AElig    => 0x00c6,
  Ccedil   => 0x00c7,
  Egrave   => 0x00c8,
  Eacute   => 0x00c9,
  Ecirc    => 0x00ca,
  Euml     => 0x00cb,
  Igrave   => 0x00cc,
  Iacute   => 0x00cd,
  Icirc    => 0x00ce,
  Iuml     => 0x00cf,
  ETH      => 0x00d0,
  Ntilde   => 0x00d1,
  Ograve   => 0x00d2,
  Oacute   => 0x00d3,
  Ocirc    => 0x00d4,
  Otilde   => 0x00d5,
  Ouml     => 0x00d6,
  times    => 0x00d7,
  Oslash   => 0x00d8,
  Ugrave   => 0x00d9,
  Uacute   => 0x00da,
  Ucirc    => 0x00db,
  Uuml     => 0x00dc,
  Yacute   => 0x00dd,
  THORN    => 0x00de,
  szlig    => 0x00df,
  agrave   => 0x00e0,
  aacute   => 0x00e1,
  acirc    => 0x00e2,
  atilde   => 0x00e3,
  auml     => 0x00e4,
  aring    => 0x00e5,
  aelig    => 0x00e6,
  ccedil   => 0x00e7,
  egrave   => 0x00e8,
  eacute   => 0x00e9,
  ecirc    => 0x00ea,
  euml     => 0x00eb,
  igrave   => 0x00ec,
  iacute   => 0x00ed,
  icirc    => 0x00ee,
  iuml     => 0x00ef,
  eth      => 0x00f0,
  ntilde   => 0x00f1,
  ograve   => 0x00f2,
  oacute   => 0x00f3,
  ocirc    => 0x00f4,
  otilde   => 0x00f5,
  ouml     => 0x00f6,
  divide   => 0x00f7,
  oslash   => 0x00f8,
  ugrave   => 0x00f9,
  uacute   => 0x00fa,
  ucirc    => 0x00fb,
  uuml     => 0x00fc,
  yacute   => 0x00fd,
  thorn    => 0x00fe,
  yuml     => 0x00ff,
  fnof     => 0x0192,
  Alpha    => 0x0391,
  Beta     => 0x0392,
  Gamma    => 0x0393,
  Delta    => 0x0394,
  Epsilon  => 0x0395,
  Zeta     => 0x0396,
  Eta      => 0x0397,
  Theta    => 0x0398,
  Iota     => 0x0399,
  Kappa    => 0x039a,
  Lambda   => 0x039b,
  Mu       => 0x039c,
  Nu       => 0x039d,
  Xi       => 0x039e,
  Omicron  => 0x039f,
  Pi       => 0x03a0,
  Rho      => 0x03a1,
  Sigma    => 0x03a3,
  Tau      => 0x03a4,
  Upsilon  => 0x03a5,
  Phi      => 0x03a6,
  Chi      => 0x03a7,
  Psi      => 0x03a8,
  Omega    => 0x03a9,
  alpha    => 0x03b1,
  beta     => 0x03b2,
  gamma    => 0x03b3,
  delta    => 0x03b4,
  epsilon  => 0x03b5,
  zeta     => 0x03b6,
  eta      => 0x03b7,
  theta    => 0x03b8,
  iota     => 0x03b9,
  kappa    => 0x03ba,
  lambda   => 0x03bb,
  mu       => 0x03bc,
  nu       => 0x03bd,
  xi       => 0x03be,
  omicron  => 0x03bf,
  pi       => 0x03c0,
  rho      => 0x03c1,
  sigmaf   => 0x03c2,
  sigma    => 0x03c3,
  tau      => 0x03c4,
  upsilon  => 0x03c5,
  phi      => 0x03c6,
  chi      => 0x03c7,
  psi      => 0x03c8,
  omega    => 0x03c9,
  thetasym => 0x03d1,
  upsih    => 0x03d2,
  piv      => 0x03d6,
  bull     => 0x2022,
  hellip   => 0x2026,
  prime    => 0x2032,
  Prime    => 0x2033,
  oline    => 0x203e,
  frasl    => 0x2044,
  weierp   => 0x2118,
  image    => 0x2111,
  real     => 0x211c,
  trade    => 0x2122,
  alefsym  => 0x2135,
  larr     => 0x2190,
  uarr     => 0x2191,
  rarr     => 0x2192,
  darr     => 0x2193,
  harr     => 0x2194,
  crarr    => 0x21b5,
  lArr     => 0x21d0,
  uArr     => 0x21d1,
  rArr     => 0x21d2,
  dArr     => 0x21d3,
  hArr     => 0x21d4,
  forall   => 0x2200,
  part     => 0x2202,
  exist    => 0x2203,
  empty    => 0x2205,
  nabla    => 0x2207,
  isin     => 0x2208,
  notin    => 0x2209,
  ni       => 0x220b,
  prod     => 0x220f,
  sum      => 0x2211,
  minus    => 0x2212,
  lowast   => 0x2217,
  radic    => 0x221a,
  prop     => 0x221d,
  infin    => 0x221e,
  ang      => 0x2220,
  and      => 0x2227,
  or       => 0x2228,
  cap      => 0x2229,
  cup      => 0x222a,
  int      => 0x222b,
  there4   => 0x2234,
  sim      => 0x223c,
  cong     => 0x2245,
  asymp    => 0x2248,
  ne       => 0x2260,
  equiv    => 0x2261,
  le       => 0x2264,
  ge       => 0x2265,
  sub      => 0x2282,
  sup      => 0x2283,
  nsub     => 0x2284,
  sube     => 0x2286,
  supe     => 0x2287,
  oplus    => 0x2295,
  otimes   => 0x2297,
  perp     => 0x22a5,
  sdot     => 0x22c5,
  lceil    => 0x2308,
  rceil    => 0x2309,
  lfloor   => 0x230a,
  rfloor   => 0x230b,
  lang     => 0x2329,
  rang     => 0x232a,
  loz      => 0x25ca,
  spades   => 0x2660,
  clubs    => 0x2663,
  hearts   => 0x2665,
  diams    => 0x2666,
  quot     => 0x0022,
  amp      => 0x0026,
  lt       => 0x003c,
  gt       => 0x003e,
  OElig    => 0x0152,
  oelig    => 0x0153,
  Scaron   => 0x0160,
  scaron   => 0x0161,
  Yuml     => 0x0178,
  circ     => 0x02c6,
  tilde    => 0x02dc,
  ensp     => 0x2002,
  emsp     => 0x2003,
  thinsp   => 0x2009,
  zwnj     => 0x200c,
  zwj      => 0x200d,
  lrm      => 0x200e,
  rlm      => 0x200f,
  ndash    => 0x2013,
  mdash    => 0x2014,
  lsquo    => 0x2018,
  rsquo    => 0x2019,
  sbquo    => 0x201a,
  ldquo    => 0x201c,
  rdquo    => 0x201d,
  bdquo    => 0x201e,
  dagger   => 0x2020,
  Dagger   => 0x2021,
  permil   => 0x2030,
  lsaquo   => 0x2039,
  rsaquo   => 0x203a,
  euro     => 0x20ac,
);

# Convert UTF-8 strings into UTF-8 encoded SGML strings, that is replace
# SGML meta-characters &<> and all 7-bit ASCII control characters
# with equivalent character entities. Optionally replace even all
# non-ASCII UTF-8 sequences with numerical character references (NCRs).
sub utf8_to_sgml {
    use Encode;
    my ($s, $opt) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/([\x00-\x08\x0b\x0c\x0e-\x1f\x7f])/sprintf("&#%d;", ord($1))/ge;
    if ($opt->{'ncr'}) {
	no bytes;
	my $u;
	$s =~ s/([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3})/$u=$1,Encode::_utf8_on($u),sprintf("&#%d;", ord($u))/ge;
    }
    return $s;
}

sub charref_to_utf8($) {
    my ($s) = @_;

    if ($s =~ /^\#([0-9]+)$/) {
	# decimal numeric character reference
	return pack("U", $1);
    } elsif ($s =~ /^\#[x]([0-9a-fA-F]+)$/) {
	# hexadecimal numeric character reference
	return pack("U", hex($1));
    } else {
	if (exists $PlexTree::SGML::entities{$s}) {
	    return pack("U", $PlexTree::SGML::entities{$s});
	} else {
	    die("Unknown SGML/HTML entity reference '$s'\n");
	}
    }
}

sub sgml_to_utf8 {
    my ($s) = @_;
    my @r = ();

    while ($s !~ /\G\z/) {
	if ($s =~ /\G([^&]+)/gc) {
	    push @r, $1;
	} elsif ($s =~ /\G&([^<>\'\";&\s]+);/gc) {
	    push @r, charref_to_utf8($1);
	} else {
	    $s =~ /\G(.)/gc;
	    push @r, $1;
	}
    }
    return join('', @r);
}

# SGML encoder

PlexTree::register_filter('sgmlenc', \&sgmlenc);

sub sgmlenc {
    my ($parent, $kref, $arg, $type) = @_;
    my $out = PlexTreeMem->new($parent, $kref);
    my $input = $type eq 'a' ? $parent : $arg->cl(0);
    die("Missing input argument in filter sgmlenc\n") unless defined $input;
    my $o;
    my %opt;
    my $public_id;
    my $system_id;
    my $dtd = '';

    # prepare options and preamble
    if (defined $input->cd(meta('xml'))) {
	$opt{'xml'} = 1;
    }
    if (defined $arg->cd('ncr')) {
	# output numerical character references instead of 
	# non-ASCII UTF-8 sequences
	$opt{'ncr'} = 1;
    }
    if (defined($o = $input->cd(meta('prescript')))) {
	# handle processing instruction that needs to appear before
	# the DOCTYPE declaration (e.g., for PHP's ob_start())
	$dtd .= join('', render($o, \%opt));
    }
    if ($opt{'xml'} && !defined($arg->cd('noxmldecl'))) {
	$dtd .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    }
    my $doctype = $input->cd('*doctype');
    # output DOCTYPE declaration if available
    if (defined $doctype and $doctype->listlen == 1) {
	my $name = $doctype->cl(0)->str;
	$public_id = $doctype->get('public');
	$system_id = $doctype->get('system');
	$dtd .= "<!DOCTYPE $name";
	if (defined $public_id) {
	    $dtd .= " PUBLIC \"$public_id\"";
	} else {
	    $dtd .= " SYSTEM";
	}
	if (defined $system_id) {
	    $dtd .= " \"$system_id\"";
	}
	$dtd .= ">\n";
    }
    # output document comment
    # (any comment that we want to add at the start of the file must
    # come after the DOCTYPE declaration, because any comment before
    # forces Internet Explorer into quirks mode)
    my $comment = $arg->get('comment');
    if (defined $comment) {
	$comment =~ s/\\/\\\\/g;     # escape backslash
	$comment =~ s/(?<=-)-/\\-/g; # escape -- by inserting backslash
	$dtd .= "<!-- $comment -->\n";
    }
    
    # read in doctype-related data
    my $doctype_arg = $arg->cd('doctype');
    if (!defined $doctype_arg && defined $public_id) {
	$doctype_arg = $PlexTree::SGML::default_doctypes->cd(text($public_id));
	#print $doctype_arg->print if DEBUG();
    }
    if (defined $doctype_arg) {
	$o = $doctype_arg->cd('empty');
	map { $opt{'empty'}->{$_->str}=1 } grep { $_->tag == TEXT } $o->keys
	    if defined $o;
    }
    
    my @s = render($input, \%opt);

    $out->setstr(join('', $dtd, @s));

    return $out;
}

sub render {
    my ($c, $opt) = @_;
    my @s = ();

    if ($c->tag == TEXT) {
	# plain text
	push @s, utf8_to_sgml($c->str, $opt);
    } elsif ($c->tag == META) {
	# element
	# start tag
	my $element = $c->str;
	push @s, '<' . $element;
	# attributes
	foreach my $d ($c->keys) {
	    next unless $d->tag == TEXT;
	    my $name = $d->str;
	    my $value = $c->cd($d);
	    if ($value->tag == TEXT) {
		push @s, " $name=";
		if ($value->isempty) {
		    $value = $name;
		} else {
		    $value = $value->str;
		}
		$value = utf8_to_sgml($value, $opt);
		if ($value =~ /\'/ >= $value =~ /\"/) {
		    $value =~ s/\"/&quot;/g;
		    push @s, '"' . $value . '"';
		} else {
		    $value =~ s/\'/&apos;/g;
		    push @s, "'" . $value . "'";
		}
	    } elsif ($value->isempty) {
		push @s, " $name";
	    } elsif ($value->tag == HYPER) {
		# SGML/HTML/XML do not permit processing instructions
		# in attribute values, but PHP programmers love them there,
		# so we need to extend our notion of SGML a bit
		push @s, " $name=\"<?", $value->str;
		push @s, ' ' unless $value->str =~ /^=?$/;
		push @s, $value->getl(0), "?>\"";
	    } elsif ($value->tag == SUPER) {
		# ASP insert
		push @s, " $name=\"<%", $value->str, "%>\"";
	    } else {
		# $value->debug(undef, {'maxdepth'=>3});
		# print $c->print;
		die("Unexpected tag value " . $value->tag .
		    " encountered in SGML tree in value of attribute ".
		    "'$name' of element '$element'\n");
	    }
	}
	if ($c->listlen) {
	    push @s, '>';
	    # element content
	    foreach my $d ($c->list) {
		push @s, render($d, $opt);
	    }
	    push @s, '</' . $c->str . '>'; # end tag
	} else {
	    # empty content
	    if ($opt->{'empty'}->{$c->str}) {
		# no end-tag required thanks to DTD
		push @s, ($opt->{'xml'} ? ' />': '>');
	    } else {
		# add end tag
		push @s, '></' . $c->str . '>';
	    }
	}
    } elsif ($c->tag == HYPER) {
	# processing instruction
	push @s, '<?' . $c->str;
	push @s, ' ' unless $c->str =~ /^=?$/;
	push @s, $c->getl(0) .'?>';
    } elsif ($c->tag == SUPER) {
	# ASP insert
	push @s, '<%' . $c->str .'%>';
    } elsif ($c->tag == TRANS) {
	# raw SGML
	push @s, $c->str;
    } else {
	# $c->debug(undef, {'maxdepth'=>2});
	die("Unexpected tag value " . $c->tag . " encountered in SGML tree\n");
    }
    
    return @s;
}

# SGML decoder

PlexTree::register_filter('sgmldec', \&sgmldec);

sub fixcase($$) {
    my ($fixcase, $s) = @_;
    if (defined $fixcase) {
	$s = uc($s) if $fixcase eq 'A';
	$s = lc($s) if $fixcase eq 'a';
    }
    return $s;
}

sub sgmldec {
    my ($parent, $kref, $arg, $type) = @_;
    my $tree = PlexTreeMem->new($parent, $kref);
    my $out = $tree; # our output cursor
    my $input = $type eq 'a' ? $parent : $arg->cl(0);
    die("Missing input argument in filter sgmldec\n") unless defined $input;
    my $s = $input->str;  # string to be parsed
    my $o;
    my $fixcase = 'a';
    my $public_id;
    my $system_id;
    my $doctype_name;
    my $xml = 0;

    # skip any UTF-8 BOM (0xef 0xbb 0xbf = U+FEFF) at start of file
    # (some Windows tools annoyingly insist on adding one, e.g. Notepad)
    $s =~ /\G\x{ef}\x{bb}\x{bf}/gc;

    # parse preamble
    while ($s !~ /\G\z/) {
	if ($s =~ /\G\s*<\?xml\s+.*?\??>\r?\n?/gc) {
	    # preserve XML declaration
	    $xml = 1;
	    my $xmldecl = $tree->addkey(meta('xml'));
	} elsif ($s =~ /\G<\?(?:([[:alpha:]_:][[:alnum:]\._:-]*)\s|(=|))(.*?)\?>/gcs) {
	    # other processing instruction
	    my $pitarget = $1 || $2;
	    my $pidata = $3;
	    # represent PI as hyper string containing the PI target,
	    # and append a text string with the PI data
	    $tree->addkey(meta 'prescript',
			  (hyper $pitarget)->append(text $pidata));
	} elsif ($s =~ /\G\s*<!DOCTYPE\s+([[:alpha:]_:][[:alnum:]\._:-]*)\s+(?:SYSTEM|PUBLIC\s+(?:\"([^\"]*)\"|\'([^\']*)\'))(?:\s+(?:\"([^\"]*)\"|\'([^\']*)\'))?\s*>\r?\n?/gc) {
	    # preserve public DOCTYPE declaration
	    $doctype_name = $1;
	    $public_id = $2 || $3;
	    $system_id = $4 || $5;
	    die("Second DOCTYPE declaration encountered")
		if (defined $tree->cd(meta('doctype')));
	    my $doctype = $tree->addkey(meta('doctype'));
	    $doctype_name = fixcase($fixcase, $doctype_name);
	    $public_id =~ s/\s+/ /g;
	    $public_id =~ s/^\s*(.*?)\s*$/$1/g;
	    $doctype->append->setstr($doctype_name);
	    $doctype->addkey('public')->setstr($public_id)
		if defined $public_id;
	    $doctype->addkey('system')->setstr($system_id)
		if defined $system_id;
	} elsif ($s =~ /\G<!(\"[^\"]*\"|\'[^\']*\'|[^\'\">]*)*>\r?\n?/gc) {
	    # skip other declarations (comments, etc.)
	} else {
	    last;
	}
    }

    # read in doctype-related options
    my $doctype = $arg->cd('doctype');
    $public_id = $arg->get('public_id') unless defined $public_id;
    if (!defined $doctype && defined $public_id) {
	$doctype = $PlexTree::SGML::default_doctypes->cd(text($public_id));
	#print $doctype->print;
    }
    my %empty;
    my %nest;
    my %nestentry;
    my %cdata;
    my %insert;
    if (defined $doctype) {
	$o = $doctype->cd('empty');
	map { $empty{$_->str}=1 } grep { $_->tag == TEXT } $o->keys
	    if defined $o;
	if (defined($o = $doctype->cd('nest'))) {
	    # iterate over entries in the nest set
	    foreach my $p ($o->keys) {
		my $v = $o->cd($p);
		# iterate over key elements -> parent elements
		foreach my $a ($p->keys) {
		    next unless $a->tag == TEXT;
		    $nestentry{$a->str} = 1;
		    # iterate over value elements -> their possible child el'ts
		    foreach my $b ($v->keys) {
			next unless $b->tag == TEXT;
			$nest{$a->str . '>' . $b->str} = 1;
		    }
		}
	    }
	}
	if (defined($o = $doctype->cd('insert'))) {
	    # iterate over entries in the insert set
	    foreach my $triggers ($o->keys) {
		next unless $triggers->len == 0; # skip comments
		my $actions = $o->cd($triggers);
		# iterate over trigger elements
		foreach my $trigger ($triggers->keys) {
		    next unless $trigger->tag == TEXT;
		    foreach my $parent ($actions->keys) {
			next if $parent->tag == CTRL;
			my $toinsert = $actions->cd($parent);
			my $p = $parent->str;
			$p = "[$p]" if $parent->tag == HYPER;
			$insert{$p . '>' . $trigger->str} =
			    $toinsert->str;
		    }
		}
	    }
	    
	}
	if (defined($o = $doctype->cd('cdata'))) {
	    map { $cdata{$_->str}=1 } grep { $_->tag == TEXT } $o->keys;
	}
	if (defined($o = $doctype->get('fixcase'))) {
	    $fixcase = $o;
	}
    }

    # parser
    my $cdata_content = 0;
    if (!defined eval {
	my $first = 1;
	while ($s !~ /\G\z/) {
	    if ($s =~ /\G&([^<>\'\";&\s]+);/gc) {
		# character entity
		my $charref = $1;
		die("Unexpected character entity '$charref' " .
		    "before first SGML element tag\n")
		    if $first;
		$out = $out->append if ($out->tag != TEXT);
		$out->appstr(charref_to_utf8($charref));
	    } elsif ($s =~ /\G&/gc) {
		# & that is not initiating a character entity
		die("Unexpected '&' " .
		    "before first SGML element tag\n")
		    if $first;
		$out = $out->append if ($out->tag != TEXT);
		$out->appstr('&');
	    } elsif ($cdata_content ?
		     ($s =~ /\G((?:(?!<\/).)+)/gcs) :
		     ($s =~ /\G([^<&]+)/gc)) {
		# regular PCDATA or CDATA
		my $cdata = $1;
		print "CDATA$cdata_content: '$cdata'\n" if DEBUG();
		if ($first) {
		    $cdata =~ s/^\s+//;
		    die("Unexpected '$1' before first " .
			"SGML element tag\n")
			if $cdata =~ /^(.{1,10})/s;
		    next;
		}
		$out = $out->append if ($out->tag != TEXT);
		$out->appstr($cdata);
		$cdata_content = 0;
	    } elsif ($s =~ /\G<!\[\s*RCDATA\s*\[(.*?)\]\]>/gcs) {
		# RCDATA marked section
		my $rcdata = $1;
		print "RCDATA section: '$rcdata'\n" if DEBUG();
		die("Unexpected RCDATA section before first " .
		    "SGML element tag\n") if $first;
		$out = $out->append if ($out->tag != TEXT);
		$out->appstr(sgml_to_utf8($rcdata));
	    } elsif ($s =~ /\G<!\[\s*CDATA\s*\[(.*?)\]\]>/gcs) {
		# CDATA marked section
		my $cdata = $1;
		print "CDATA section: '$cdata'\n" if DEBUG();
		die("Unexpected CDATA section before first " .
		    "SGML element tag\n") if $first;
		$out = $out->append if ($out->tag != TEXT);
		$out->appstr($cdata);
	    } elsif ($s =~ /\G<!\[\s*IGNORE\s*\[(.*?)\]\]>/gcs) {
		# ignore IGNORE marked section
	    } elsif ($s =~ /\G(<!--\[if [^\]]+\]>(?:[^-]|-[^-])*<!\[endif\]-->)/gc ||
		     $s =~ /\G(<!\[if [^\]]+\]>.*?<!\[endif\]>)/gc) {
		# preserve Internet Explorer conditional comments
		# http://msdn.microsoft.com/en-us/library/ms537512%28v=vs.85%29.aspx
		my $cc = $1;
		# close character data
		if ($out->tag == TEXT) {
		    $out = $out->parent;
		}
		$out->append(trans $cc);
	    } elsif ($s =~ /\G<!--(?:[^-]|-[^-])*-->/gc) {
		# skip comment
	    } elsif ($s =~ /\G<\?(?:([[:alpha:]_:][[:alnum:]\._:-]*)\s|(=|))(.*?)\?>/gcs) {
		# processing instruction
		my $pitarget = $1 || $2;
		my $pidata = $3;
		# close character data
		if ($out->tag == TEXT) {
		    $out = $out->parent;
		}
		# represent PI as hyper string containing the PI target,
		# and append a text string with the PI data
		$out->append->set(hyper $pitarget)->append(text $pidata);
	    } elsif ($s =~ /\G<%(.*?)%>/gcs) {
		# <%...%> insert (used by Microsoft's Active Server Pages, ASP)
		my $data = $1;
		# close character data
		if ($out->tag == TEXT) {
		    $out = $out->parent;
		}
		# represent ASP insert as super string containing the ASP code
		$out->append->set(super $data);
	    } elsif ($s =~ /\G(<([[:alpha:]_:][[:alnum:]\._:-]*)((?:\s+[[:alpha:]_:][[:alnum:]\._:-]*\s*(?:=\s*\"[^\"]*\"|=\s*\'[^\']*\'|=\s*[^\'\">\s\/]*||=\s*\"<\?.*?\?>\"|=\s*\"<%.*?%>\"|))*)\s*(\/?)>)\r?\n?/gc) {
		# element start tag
		my $starttag = $1;
		my $element = $2;
		my $att = $3;
		my $end = $4;
		$element = fixcase($fixcase, $element);
		# close character data
		if ($out->tag == TEXT) {
		    $out = $out->parent;
		}
		# should we close anything else first?
		while (exists $nestentry{$out->str} &&
		       !exists $nest{$out->str . '>' . $element}) {
		    print "AUTO-END ELEMENT " . $out->str . "\n" if DEBUG();
		    $out = $out->parent;
		    die("SGML element '$element' is not permitted here\n")
			unless defined $out && $out->tag == META;
		}
		# should we open anything first?
		my $parent = $out->parent;
		my $toinsert;
		while (1) {
		    if ($out->tag == META) {
			$parent = $out->str;
		    } else {
			$parent = '[ROOT]';
		    }
		    $toinsert = $insert{$parent.'>'.$element};
		    last unless defined $toinsert;
		    # append new element
		    my $new;
		    if ($first) {
			$new = $out;
			undef $first;
		    } else {
			$new = $out->append;
		    }
		    print "AUTO-START ELEMENT $toinsert\n" if DEBUG();
		    $new->settstr(META, $toinsert);
		    $parent = $out;
		    $out = $new;
		}
		# append new element
		my $new;
		if ($first) {
		    $new = $out;
		    undef $first;
		} else {
		    $new = $out->append;
		}
		$new->settstr(META, $element);
		$cdata_content = $cdata{$element};
		print "START ELEMENT $element\n" if DEBUG();
		# parse attributes
		if (defined $att) {
		    while ($att !~ /\G\z/) {
			if ($att =~ /\G\s+([[:alpha:]_:][[:alnum:]\._:-]*)\s*=\s*\"<\?(?:([[:alpha:]_:][[:alnum:]\._:-]*)\s|(=|))(.*?)\?>\"/gc) {
			    my $name = $1;
			    my $pitarget = $2 || $3;
			    my $pidata = $4;
			    # represent PI as hyper string containing the PI target,
			    # and append a text string with the PI data
			    $new->addkey($name)->set(hyper $pitarget)->append(text $pidata);
			} elsif ($att =~ /\G\s+([[:alpha:]_:][[:alnum:]\._:-]*)\s*=\s*\"<%(.*?)%>\"/gc) {
			    my $name = $1;
			    my $data = $2;
			    # represent ASP insert as super string
			    $new->addkey($name)->set(super $data);
			} elsif ($att =~ /\G\s+([[:alpha:]_:][[:alnum:]\._:-]*)\s*=\s*\"([^\"]*)\"/gc ||
				 $att =~ /\G\s+([[:alpha:]_:][[:alnum:]\._:-]*)\s*=\s*\'([^\']*)\'/gc ||
				 $att =~ /\G\s+([[:alpha:]_:][[:alnum:]\._:-]*)\s*=\s*([a-zA-Z0-9\._:-]+)/gc) {
			    # normal attribute=value pair
			    my $name = $1;
			    my $value = $2;
			    $name = fixcase($fixcase, $name);
			    my $v = $new->addkey($name);
			    if (defined $value) {
				$v->setstr(sgml_to_utf8($value));
			    }
			    print "  ATTRIBUTE $name='$value'\n" if DEBUG();
			} elsif ($att =~ /\G\s+([[:alpha:]_:][[:alnum:]\._:-]*)/gc) {
			    my $name = $1;
			    $name = fixcase($fixcase, $name);
			    $new->addkey($name);
			    print "  ATTRIBUTE $name\n" if DEBUG();
			} elsif ($att !~ /\G\s+/gc) {
			    die("Unexpected character sequence encountered in SGML tag attributes '$att'\n");
			}
		    }
		}
		# consider self-ending start tags
		if ($end eq '/' || exists $empty{$element}) {
		    # element is already finished here
		    $cdata_content = 0;
		    print "SELF-END ELEMENT $element\n" if DEBUG();
		} else {
		    $out = $new;
		}
	    } elsif ($s =~ /\G(<\/([[:alpha:]_:][[:alnum:]\._:-]*)\s*>)/gc) {
		# element end tag
		my $endtag = $1;
		my $element = $2;
		$element = fixcase($fixcase, $element);
		# close character data
		if ($out->tag == TEXT) {
		    $out = $out->parent;
		}
		$cdata_content = 0;
		# close elements until one is encountered that matches $element
		my $leaving;
		while (1) {
		    $leaving = $out;
		    $out = $out->parent;
		    last if $leaving->tag == META && $leaving->str eq $element;
		    print "AUTO-END ELEMENT ".$leaving->str."\n" if DEBUG();
		    die("SGML tag $endtag attempts to close an element ".
			"'$element' that was not open\n")
			unless (defined $out && $leaving->nid != $tree->nid)
		};
		print "END ELEMENT " . $leaving->str . "\n" if DEBUG();
		if ($leaving->nid == $tree->nid) {
		    # now only whitespace and comments may be left
		    $s =~ /\G\s*(?:<!--([^-]|-[^-])*-->\s*)*/gc;
		    die("Unexpected '$1' after end of top-level " .
			"SGML element '$element'\n")
			if $s =~ /\G(.{1,10})/s;
		}
	    } else {
		die("Unexpected character sequence encountered in SGML file\n");
	    }
	    print "PATH: " . join('/', map {$_->tag == META() &&
						$_->str} $out->path)
		. "\n" if DEBUG();
	}
    }) {
	# exception handling
	my $err = PlexTreeMem->new;
	chomp($@);
	$err->setstr($@);
	#$err->addkey('input_suffix')->setstr($s);
	#$err->addkey('input')->setstr($str->str);
	# determine line and column position of error
	my $char = pos $s;
	my @l = split(/\n/, $input->str);
	my $line = 0;
	while ($char > 0 && $char - (length($l[$line]) + 1) >= 0) {
	    $char -= length($l[$line]) + 1;
	    $line++;
	}
	$err->addkey('line')->setstr($l[$line]);
	$err->addkey('errrow')->setstr($line + 1);
	$err->addkey('errcol')->setstr($char + 1);
	die($err);
    }

    return $tree;
}

# The DTD used below differes in minor aspect from the W3C spec and is
# slightly more generous to allow for historic practice and some
# broken XHTML generators:
#
# - addition of Netscape's <embed> and <noembed> elements according to
#   http://www.yoyodesign.org/doc/dtd/html4-embed.html.en
#
# - in the XHTML 1.0 spec, <script> and <style> have actually PCDATA
#   content, not CDATA as in HTML and here, so we are a
#   bit more tolerant here, since too few people fully understand all
#   the restrictions of XHTML

our $default_doctypes = c(<<'EOT');
(
  "-//W3C//DTD HTML 4.01//EN"=(
    empty={
       .c='Elements with no content that close themselves',
       area, base, basefont, br, col, frame, hr, img, input, isindex,
       link, meta, param
    },
    insert={
       .c='Opening element A listed here as {A}(B=C) will cause C to be opened first if B is the most recently open element',
       {tr}={table=tbody},
       {.c='%flow;', p, h1, h2, h3, h4, h5, h6, ul, ol, pre, dl, div,
        noscript, blockquote, form, hr, table, fieldset,
        address, noembed, script, tt, i, b, u, s, strike, big, small,
        em, strong, dfn, code, samp, kbd, var, cite, abbr,
        acronym, a, img, applet, object, font, basefont, br,
        script, map, q, sub, sup, span, bdo, iframe, embed,
        input, select, textarea, label, button, +PCDATA
       }={html=body, +ROOT=html},
       {head, body, frameset}={ +ROOT=html },
       {title, base, script, style, meta, link, object}={html=head, +ROOT=html}
    },
    nest={
       .c='If an open element is listed here, then an attempt to open another element than the one listed here under it will close the open element first',
       {head}={title, base, script, style, meta, link, object},
       {title,script,style}=,
       {p,dt}={.c='%inline;', tt, i, b, u, s, strike, big, small,
        em, strong, dfn, code, samp, kbd, var, cite, abbr,
        acronym, a, img, applet, object, font, basefont, br,
        script, map, q, sub, sup, span, bdo, iframe, embed,
       input, select, textarea, label, button, +PCDATA},
       {li,th,td,dd}={.c='%flow;',
            p, h1, h2, h3, h4, h5, h6, ul, ol, pre, dl, div, center,
            noscript, noframes, blockquote, form, isindex, hr, table, fieldset,
            address, noembed, script, tt, i, b, u, s, strike, big, small,
            em, strong, dfn, code, samp, kbd, var, cite, abbr,
            acronym, a, img, applet, object, font, basefont, br,
            script, map, q, sub, sup, span, bdo, iframe, embed,
            input, select, textarea, label, button, +PCDATA},
       {option}={+PCDATA},
       {thead, tfoot, tbody}={tr},
       {colgroup}={col},
       {tr}={th,td}
    },
    cdata={script, style},
    fixcase='a'
  ),
  "-//W3C//DTD HTML 3.2 Final//EN"        =.sr("-//W3C//DTD HTML 4.01//EN"),
  "-//W3C//DTD HTML 4.0//EN"              =.sr("-//W3C//DTD HTML 4.01//EN"),
  "-//W3C//DTD HTML 4.0 Transitional//EN" =.sr("-//W3C//DTD HTML 4.01//EN"),
  "-//W3C//DTD HTML 4.01 Transitional//EN"=.sr("-//W3C//DTD HTML 4.01//EN"),
  "-//W3C//DTD XHTML 1.0 Strict//EN"      =.sr("-//W3C//DTD HTML 4.01//EN"),
  "-//W3C//DTD XHTML 1.0 Transitional//EN"=.sr("-//W3C//DTD HTML 4.01//EN")
)
EOT

sub html_cleanup {
    my ($h) = @_;
    
    return unless $h->tag == META;
    my $el = lc($h->str);
    # collapse consecutive strings
    for (my $i = 0; $i < $h->listlen - 1; $i++) {
	my $this = $h->cl($i);
	if ($this->tag == TEXT) {
	    my $next;
	    while (defined($next = $h->cl($i+1)) &&
		   $next->tag == TEXT) {
		$this->setstr($this->str . $next->str);
		$next->cut;
	    }
	}
    }
    if ($el =~ /^pre|script|style$/) {
	# do not touch any whitespace in preformatted and non-HTML text
	return;
    } elsif ($el =~ /^html|head|table|thead|tbody|tr|ul|ol|dl|select$/) {
	# any white-space in PCDATA children and empty PCDATA children
	# can be removed
	foreach my $c ($h->list) {
	    if ($c->tag == TEXT()) {
		my $s = $c->str;
		$s =~ s/^\s+//;
		$s =~ s/\s+$//;
		$s =~ s/\s+/ /;
		if ($s eq '') {
		    $c->cut;
		} else {
		    $c->setstr($s);
		}
	    } else {
		html_cleanup($c);
	    }
	}
    } elsif ($el =~ /^p|h[1-6]|div|center|blockquote|address|tt|i|b|u|s|strike|big|small|em|strong|dfn|code|samp|kbd|var|cite|abbr|acronym|a|font|sub|sup|span|$/) {
	# initial and final whitespace can be removed, intermediate
	# whitespace and strings can be collapsed
	my $c;
	# remote initial whitespace
	if (defined($c = $h->cl(0)) && $c->tag == TEXT) {
	    my $s = $c->str;
	    $s =~ s/^\s+//;
	    if ($s eq '') {
		$c->cut;
	    } else {
		$c->setstr($s);
	    }
	}
	# remote final whitespace
	if (defined($c = $h->cl($h->listlen - 1)) && $c->tag == TEXT) {
	    my $s = $c->str;
	    $s =~ s/\s+$//;
	    if ($s eq '') {
		$c->cut;
	    } else {
		$c->setstr($s);
	    }
	}
	# remove intermediate whitespace
	foreach $c ($h->list) {
	    if ($c->tag == TEXT) {
		my $s = $c->str;
		$s =~ s/\s+/ /g;
		if ($s eq '') {
		    $c->cut;
		} else {
		    $c->setstr($s);
		}
	    }
	}
	# recurse
	foreach $c ($h->list) {
	    html_cleanup($c);
	}
    } else {
	# just recurse
	foreach my $c ($h->list) {
	    html_cleanup($c);
	}
    }
}

1;
