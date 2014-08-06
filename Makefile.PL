use strict;
#use 5.005062;
use ExtUtils::MakeMaker;
use Config;

# TODO: we should provide an option to provide a B::CC compiled script/phash,
# which would e.g. use faster versions of the pure perl modules.

# TODO try c compiler and extract cmph and bob then
#use ExtUtils::Embed;

# Note: These 2 Makefiles will be overwritten later by recursive WriteMakefile
# So generate all required binaries here
if (! -e "cmph-2.0/configure") {
  system("tar xfz cmph-2.0.tar.gz");
  if (-e "cmph-2.0/configure") {
    chdir "cmph-2.0";
    system("./configure --prefix=`pwd`");
    system($Config{'make'}, "-s");
    system($Config{'make'}, "-s", "install");
    rename "Makefile", "Makefile.orig";
    chdir "..";
  }
}

if (! -e "bob/lookupa.c") {
  system("git clone git://github.com/rurban/jenkins-minimal-perfect-hash.git bob");
  if (-e "bob/lookupa.c") {
    chdir "bob";
    my $cc = $Config{cc};
    if ($cc ne "gcc") {
      `$^X -pi.bak -e's/gcc/$cc/' Makefile`;
    }
    system($Config{'make'}, "-s");
    rename "Makefile", "Makefile.orig";
    chdir "..";
  }
}

WriteMakefile
  (
   'NAME'	   => 'Perfect::Hash',
   'VERSION_FROM'  => 'lib/Perfect/Hash.pm',
   'ABSTRACT_FROM' => 'lib/Perfect/Hash.pm',
   'PL_FILES'   => { 'script/phash.PL' => 'script/phash' },
   'EXE_FILES'  => [ 'script/phash' ],
   'LIBS'       => "-lz",
   'PREREQ_PM'	=> {
     #'coretypes' => 0,
   },
   AUTHOR        => 'Reini Urban',
   ($ExtUtils::MakeMaker::VERSION gt '6.46' ?
    ('META_MERGE'  =>
     {
      resources =>
      {
       repository  => 'http://github.com/rurban/Perfect-Hash',
       license     => 'http://dev.perl.org/licenses/',
      },
     }
    ) : ()),
    SIGN => 1
  );


package MY;

sub dist {
  local $_ = shift->SUPER::dist(@_);
  s/DIST_DEFAULT = /DIST_DEFAULT = README.md /;
  return $_;
}

sub depend {
  "
README.md : \$(VERSION_FROM)
	pod2markdown \$(VERSION_FROM) > \$@

release : dist
	git commit -a -m\"release \$(VERSION)\"
	git tag \$(VERSION)
	cpan-upload \$(DISTVNAME).tar\$(SUFFIX)
	git push
	git push --tags
test_cover :: pure_all
	\$(RM_RF) cover_db
	\$(PERLRUNINST) -S cover -test
test_coveralls :: pure_all
	\$(PERLRUNINST) -S cover -test -report coveralls
"
}
