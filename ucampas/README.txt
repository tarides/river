
ucampas - University of Cambridge Page Augmentation System
----------------------------------------------------------

Markus Kuhn -- http://www.cl.cam.ac.uk/~mgk25/

The page-formatting tool ucampas converts simple HTML files into web
pages that follow a house style. It was initially developed for
formatting the web sites of the University of Cambridge Computer
Laboratory and Wolfson College Cambridge. It can readily be used to
format other websites associated with the University of Cambridge. (To
adapt ucampas for use by other organizations, additional house-style
templates have to be written, which is possible but not yet fully
documented. See templates/README.txt for more information)

For more information on how to use and configure ucampas, please read

  http://www.cl.cam.ac.uk/local/web/ucampas/


Installation prerequisites:

  - some form of Linux or Unix
  - Perl 5.8.1 or newer

Installation instructions:

1) If you received a ucampas.tar.gz distribution file, unpack it
   wherever you want it to reside. In the following examples, the
   ucampas installation directory will be /opt/ucampas. Unpacking
   the distribution there e.g. with

     mkdir -p /opt/ucampas
     cd /opt/ucampas
     tar xzvf .../ucampas.tar.gz

   Alternatively, you can install ucampas (and the perl-PlexTree
   library that it uses) via the git version-control system:

     cd /opt
     git clone http://www.cl.cam.ac.uk/~mgk25/git/ucampas ucampas
     git clone http://www.cl.cam.ac.uk/~mgk25/git/perl-PlexTree ucampas/perl-PlexTree

  Using git has the advantage that updating to the latest version
  becomes as easy as

     cd /opt/ucampas/perl-PlexTree && git pull && cd .. && git pull

2) Create symbolic links such that users will find the ucampas
   user command and associated convenience scripts in their $PATH,
   e.g. with

     ln -s /opt/ucampas/ucampas           /usr/local/bin/
     ln -s /opt/ucampas/ucampas-clean     /usr/local/bin/
     ln -s /opt/ucampas/ucampas-grep      /usr/local/bin/
     ln -s /opt/ucampas/ucampas-navtest   /usr/local/bin/
     ln -s /opt/ucampas/ucampas-svnignore /usr/local/bin/

3) Optional: create a global uconfig.txt file in the ucampas
   installation directory (i.e., /opt/ucampas/uconfig.txt) that
   defines some site-wide default settings. For example, you can set
   there the name of your organization, the default style template to
   be used, the URLs where style sheets can be found, etc.:

     organization="Computer Laboratory",
     style=ucam2008,
     stylesheets_url="http://www.cl.cam.ac.uk/style/",
     images_url="http://www.cl.cam.ac.uk/images/",
     change_check=1,
     umask='0002',
     search=google(domains="cam.ac.uk;www.cl.cam.ac.uk",
                   sitesearch="www.cl.cam.ac.uk"),
     headlinks=(
       ("Contact us", href="http://www.cl.cam.ac.uk/contact/"),
       ("A–Z", href="http://www.cl.cam.ac.uk/az/"),
       ("Advanced search", href="http://www.cl.cam.ac.uk/search/"),
     ),

   Alternatively, you can also set all these defaults in the
   uconfig.txt file in the root directory of your web site.

   See http://www.cl.cam.ac.uk/local/web/ucampas/ref.html for the
   syntax specification and a list of all supported configuration
   parameters.

Support:

You might be interested in joining the cl-ucampas-announce mailing
list at

  https://lists.cam.ac.uk/mailman/listinfo/cl-ucampas-announce

to receiver occasional announcements of new features and developments.

If you have any questions regarding ucampas, best ask on the
cl-ucampas-discuss mailing list at

  https://lists.cam.ac.uk/mailman/listinfo/cl-ucampas-discuss


Integrating ucampas with Subversion:

Ucampas can be used on its own as just an HTML page-formatting tool
that converts *-b.html files into house-style decorated *.html files.
(You should familiarize yourself with using it in that way before
reading on.)

Ucampas also comes with an additional script commit-update.pl with
which it can be integrated with the Subversion revision control system
into a more full-featured content-management system (notably one that
requires neither dynamic web page techniques such as CGI or PHP, nor
an SQL server). This can help multiple contributors to collaborate on
a web site (and also allows Windows users to contribute). In such a
setup, the website is edited via Subversion. Contributors checkout the
website as a personal subversion working directory, edit it, and run
ucampas locally to preview how their edits will look like. They then
commit their changes back to the repository. Only the manually edited
*-b.html files are kept in the repository, but not the *.html pages
that ucampas generates from them. (Windows users can use the
TortoiseSVN GUI, but can't do a local preview as ucampas has not yet
been ported to Windows.)

The web server has its own subversion working directory (which should
be owned by a special pseudouser). We adjust the post-commit hook
script in the Subversion repository to call after each successful
commit operation the provided commit-update.pl script, which
essentially does an "svn update" and "ucampas -r" over the web
server's working directory, such that the commited changes become
visible on the public website.

(What commit-update.pl actually does is slightly more complicated.
Firstly, it takes care to remove any ucampas-generated files from any
subdirectories that the following "svn update" is about to remove, to
keep everything nice and tiny when directories are moved or deleted,
as "svn update" will not delete directories that still contain files
not under revision control. The script also reformats immediately
*-b.html files that were modified in a commit, and then starts a
background job that reformats the rest of the website, to update any
navigation information elsewhere that might have been affected by the
modification.)

A simple repository/hooks/post-commit script might look like

REPOS="$1"
REV="$2"
AUTHOR=`svnlook author "$REPOS" --revision "$REV"`
sudo -u wwwupdate /opt/ucampas/commit-update.pl "$REPOS" "$REV" \
        /srv/www/htdocs/ -q -s trunk/ -u /opt/ucampas/ucampas

[In practice, repository/hooks/post-commit might also call
commit-email.pl (comes with Subversion) to notify interested people
about commits. Note that we use here sudo to switch from the user that
owns the repository to the wwwupdate pseudouser that owns the web
server's working directory, to protect the repository against
accidental or malicious modification, just in case ucampas has any
vulnerabilities.]
