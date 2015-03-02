package PlexTree::FileSys;

use strict;
use bytes;
no locale;
use PlexTree;

our @ISA = ('PlexTree');

PlexTree::register_substitution_filter('filesys', \&filesys);

sub filesys {
    my ($parent, $kref, $arg) = @_;
    my $rootpath;
    my $input = $arg->cl(0);
    
    if (defined $input && $input->tag == TEXT) {
	$rootpath = $input->str;
    } else {
	$rootpath = '/';
    }

    return bless([ $parent, $kref, $parent->[2], $parent->[3], $rootpath ]
		 => 'PlexTree::FileSys');
}

sub tag {
    my ($self, $pos, $len) = @_;
    my ( $parent, $kref, undef, undef, $path ) = @{$self};

    if (-f $path) {
	return TEXT if (-T $path);
	return BINARY;
    }

    return CTRL;
}

sub str {
    my ($self, $pos, $len) = @_;
    my ( $parent, $kref, undef, undef, $path ) = @{$self};
    my $f;
    my $s;

    if (-f $path) {
	open($f, '<', $path) || die("$path:$!");
	seek $f, $pos, 'SEEK_SET' if $pos;
	if (defined $len) {
	    read $f, $s, $len;
	} else {
	    local $/;
	    $s = <$f>;
	}
	close $f;
	return $s;
    }

    return '';
}

sub keys {
    my ($self, $pos, $len) = @_;
    my ( $parent, $kref, undef, undef, $path ) = @{$self};
    my $d;
    my @keys = ();

    return () if -l $path;

    if (-d $path) {
	opendir($d, $path) || die("$path:$!");
	push @keys, map { text($_) } grep { !/^\.\.?$/ && !-l $_ } readdir($d);
	closedir $d;
    }

    @keys = sort @keys;

    return @keys;
}

sub cd_r {
    my ($self, $fn) = @_;
    my ( $parent, $kref, $nosub, $env, $path ) = @{$self};

    return if $fn->tag != TEXT || $fn->dirlen != 0 || $fn->listlen != 0;
    $fn = $fn->str;
    die("Encountered '/' in filename '$fn'\n") if $fn =~ /\//;
    die("Encountered zero byte in filename '$fn'\n") if $fn =~ /\0/;
    die("Empty filename '$fn'\n") if $fn eq '';
    
    $path .= '/' unless $path =~ /\/$/;
    $path .= $fn;

    if (-e $path) {
	my $k = text($fn)->crfs;
        return bless([ $self, \$k, $nosub, $env, $path ]
		     => 'PlexTree::FileSys');
    }
    
    return;
}

sub parent {
    my ($self) = @_;
    return $self->[0];
}

sub key {
    my ($self) = @_;
    return $self->[1];
}

1;
