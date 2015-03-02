#!/usr/bin/env perl
# Test example:
# ./commit-update.pl /usr/groups/wwwsvn/repositories/vh-cl 170 /home/mgk25/public_html/cl-preview/html -s trunk/html/

use strict;

my $usage =
    "Subversion post-commit script: updates files in a given\n".
    "working directory and calls ucampas where appropriate\n\n".
    "usage: $0 REPOS REVNUM working_dir [options]\n\n".
    "options:\n\n".
    "  -s strip_prefix    remove this prefix from pathname in repository\n".
    "                     before appending the rest to working directory\n".
    "  -m match_regexp    process only files whose path in the repository\n".
    "                     (after -s was applied) matches this regular expr.\n".
    "  -q                 quiet mode: output only error messages\n".
    "  -l logfile         write command output to this logfile\n".
    "                     (relative paths are relative to working_dir)\n".
    "  -e addr{,addr}     send command output to these email addresses ...\n".
    "  -c addr{,addr}     ... and these Cc: addresses ...\n".
    "  -f addr            ... using this From: address\n".
    "  -r rootdir         ucampas top-level directory where background\n".
    "                     update should start (if not in working_dir)\n".
    "                     (relative paths are relative to working_dir)\n".
    "  -u ucampas_path    path of ucampas executable (if not on \$PATH)\n".
    "  -M                 execute 'make' in any changed directory that\n".
    "                     contains a 'Makefile'\n";

my $repos  = shift @ARGV;
my $revnum = shift @ARGV;
my $wdir   = shift @ARGV;
my $pattern;
my $prefix;
my $callmake;

my $maxargs = 20;
my $ucampas = "ucampas";
my $errors = 0;
my $quiet = '';

my $log;
my $logfile;
my $emails;
my $cc;
my $from = 'webmaster';
my $rdir = $wdir;

umask 002;

# Quote a string for the shell (surround with "..." and
# escape $`"\ with backslash)
sub shellquote($) {
    my ($s) = @_;

    $s =~ s/([\$\`\"\\])/\\$1/g;
    $s = '"' . $s . '"';

    return $s;
}

sub cmd {
    my ($cmd) = @_;
    $log .= "$cmd\n" unless $quiet;
    $log .= `$cmd 2>&1`;
    if ($?) {
	$log .= "Failed command: $cmd\n";
	$errors++;
    }
}

sub command {
    my ($prog, @args) = @_;

    # deal only with owned or not (yet) existing files
    @args = grep { -o $_ || ! -e $_ } @args;
    @args = map { shellquote($_) } @args;
    while (@args) {
	cmd("$prog ". join(' ', splice(@args, 0, $maxargs)));
    }
}

eval {

    die $usage unless ($repos && $revnum && $wdir);
    
    while (@ARGV) {
	my $arg = shift @ARGV;
	if ($arg =~ /^-m$/) {
	    $pattern = shift @ARGV;
	} elsif ($arg =~ /^-M$/) {
	    $callmake = 1;
	} elsif ($arg =~ /^-q$/) {
	    $quiet = ' -q';
	} elsif ($arg =~ /^-s$/) {
	    $prefix = shift @ARGV;
	} elsif ($arg =~ /^-l$/) {
	    $logfile = shift @ARGV;
	    $logfile = "$wdir/$logfile" unless $logfile =~ /^\//;
	} elsif ($arg =~ /^-e$/) {
	    $emails = shift @ARGV;
	} elsif ($arg =~ /^-c$/) {
	    $cc = shift @ARGV;
	} elsif ($arg =~ /^-f$/) {
	    $from = shift @ARGV;
	} elsif ($arg =~ /^-r$/) {
	    $rdir = shift @ARGV;
	    $rdir = "$wdir/$rdir" unless $rdir =~ /^\//;
	} elsif ($arg =~ /^-u$/) {
	    $ucampas = shift @ARGV;
	} else {
	    die "unexpected option '$arg'\n" . $usage;
	}
    }
    
    $log .= `svn log -v file://$repos --revision $revnum` unless $quiet;
    
    my $cmd = "svnlook dirs-changed $repos --revision $revnum";
    $_ = `$cmd`; $? and die("Failed command: $cmd\n");
    chomp;
    my @changed_dirs = split /\n/;
    
    $cmd = "svnlook changed $repos --revision $revnum";
    $_ = `$cmd`; $? and die("Failed command: $cmd\n");
    chomp;
    my @updated_files = split /\n/;
    my @deleted_files = grep /^D.. .*[^\/]$/, @updated_files;
    my @deleted_dirs  = grep /^D.. .*\/$/,    @updated_files;
    my @changed_files = grep /^[UAG].. /,     @updated_files;
    @deleted_files = grep { s/^... //; } @deleted_files;
    @deleted_dirs  = grep { s/^... //; } @deleted_dirs;
    @changed_files = grep { s/^... //; } @changed_files;

    if (defined $prefix) {
	@changed_dirs = map {
	    (substr($_, 0, length($prefix)) eq $prefix) ? 
		substr($_, length($prefix)) : ();
	} @changed_dirs;
	@deleted_files = map {
	    (substr($_, 0, length($prefix)) eq $prefix) ? 
		substr($_, length($prefix)) : ();
	} @deleted_files;
	@deleted_dirs = map {
	    (substr($_, 0, length($prefix)) eq $prefix) ? 
		substr($_, length($prefix)) : ();
	} @deleted_dirs;
	@changed_files = map {
	    (substr($_, 0, length($prefix)) eq $prefix) ? 
		substr($_, length($prefix)) : ();
	} @changed_files;
    }
    
    if (defined $pattern) {
	@changed_dirs  = grep { /$pattern/ } @changed_dirs;
	@deleted_files = grep { /$pattern/ } @deleted_files;
	@deleted_dirs  = grep { /$pattern/ } @deleted_dirs;
	@changed_files = grep { /$pattern/ } @changed_files;
    }
    
    @changed_dirs  = map { "$wdir/$_" } @changed_dirs;
    @deleted_files = map { "$wdir/$_" } @deleted_files;
    @deleted_dirs  = map { "$wdir/$_" } @deleted_dirs;
    @changed_files = map { "$wdir/$_" } @changed_files;
    
    # remove files whose ucampas sources are about to be deleted
    command('rm -f', grep { s/-b(\.(?:html?|php))$/$1/i && -e } @deleted_files);
    # same for all *-b.html generated *.html files in
    # about-to-be-deleted directories
    foreach my $deleted_dir (@deleted_dirs) {
	cmd("find '$deleted_dir' -name .svn -prune -o -iregex '.*-b\\.\\(html?\\|php\\)\\|.*~' -print0 | perl -0 -pe 's/-b(\\.(?:html?|php)\\0)\$/\\1/i' | xargs --no-run-if-empty -0 rm -f");
    }
    
    # update any affected directories
    # (earlier attempts with "svn update -N" broke way too much)
    command("svn update --ignore-externals" . $quiet, @changed_dirs);
    
    # call ucampas on any added, updated or merged *-b.html files
    my @changed_b_files = grep { /-b\.(?:html?|php)$/i } @changed_files;
    command($ucampas . $quiet, @changed_b_files);
    # ensure that ucampas does get called if a uconfig.txt file was changed,
    # such that problems there are reported back to the committer instantly
    my @changed_uconfig_files = grep { /^(?:.*\/)?uconfig.txt$/ } @changed_files;
    if (@changed_uconfig_files && !@changed_b_files) {
	# rebuild root page to test uconfig.txt changes
	# (todo: rebuild instead index of directory where the
	# changed uconfig.txt file resides)
	command($ucampas . $quiet, "$rdir/") if $rdir;
    }

    if ($callmake) {
	foreach my $makedir (@changed_dirs) {
	    next unless -r "$makedir/Makefile";
	    command('make' . ($quiet ? ' -s' : '') . ' -C', $makedir);
	}
    }
    
};
if ($@) {
    $log .= $@;
    $errors++;
}


print STDERR $log;
if (defined $logfile) {
    open(LOG, '>>', $logfile);
    print LOG $log;
    close LOG;
}
if (defined $emails && $errors) {
    open(MAIL, '| sendmail -t -B 8BITMIME -i -f ' . $from);
    print(MAIL
	  "From: $from\n" .
	  "To: $emails\n" .
	  ($cc ? "Cc: $cc\n" : '') .
	  "Subject: problem with svn-commit r$revnum\n" .
	  "X-script: $0\n" .
	  "X-repository: $repos\n" .
	  "X-wdir: $wdir\n" .
	  "Mime-version: 1.0\nContent-type: text/plain; charset=UTF-8\n\n" .
	  "This is an automatically generated commit-update " .
	  "error message.\n" .
	  "When processing svn commit $revnum, " . 
	  "this problem occurred:\n\n$log");
    close MAIL;
}

if ($rdir) {
    # Finally, trigger a rebuild of the entire main site as a background job
    # to cover changes to navigation structure, sitemap, etc.
    # Make sure that not more than one of these jobs is running concurrently,
    # by terminating an already running one before starting the new one.
    my $qrdir = shellquote($rdir);
    if (open(PID, '<', "$rdir/.backgroundpid")) {
	kill TERM => <PID>;
	close PID;
	sleep 2;  # give the background rm a chance to finish first
	unlink "$rdir/.backgroundpid";  # just to be save
    }
    unlink "$rdir/.backgroundlog";
    `{ nice sh -c 'echo \$\$ >$qrdir/.backgroundpid ; exec $ucampas -r $qrdir' ; rm -f $qrdir/.backgroundpid ; } </dev/null >$qrdir/.backgroundlog 2>&1 &`;
}

exit $errors > 0;
