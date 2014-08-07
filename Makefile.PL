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
  print "Extracting cmph-2.0.tar.gz\n";
  system("tar xfz cmph-2.0.tar.gz");
}

if (! -e "bob/lookupa.c") {
  print "Cloning git://github.com/rurban/jenkins-minimal-perfect-hash.git to bob\n";
  system("git clone git://github.com/rurban/jenkins-minimal-perfect-hash.git bob");
  if (-e "bob/lookupa.c" and !-e "bob/perfect".$Config{exe_ext}) {
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
   clean => { FILES => "Hash.c.gcov Hash.xs.gcov Hash.gcda Hash.gcno "
                      ."cover_db perf.data script/phash" },

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

# ensure README.md is uptodate at least when doing a dist
sub dist {
  local $_ = shift->SUPER::dist(@_);
  s/DIST_DEFAULT = /DIST_DEFAULT = README.md /;
  return $_;
}

sub depend { '
README.md : $(VERSION_FROM)
	pod2markdown $(VERSION_FROM) | \
	  $(PERL) -pe\'s/png\]\(https:/png\)\](https:/; s/(Travis|Coveralls): \[/\[!\[\1]\(/;\' > $@

release : dist
	git commit -a -m"release $(VERSION)"
	git tag $(VERSION)
	cpan-upload $(DISTVNAME).tar$(SUFFIX)
	git push
	git push --tags
test_cover :: pure_all
	$(RM_RF) cover_db
	$(PERLRUNINST) -S cover -test
test_coveralls :: pure_all
	test -f .coveralls.yml && $(PERLRUNINST) -S cover -test -report coveralls
'; }
