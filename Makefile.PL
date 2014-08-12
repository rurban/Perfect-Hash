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

my @extras = ();
my $EUMM_VER = $ExtUtils::MakeMaker::VERSION;
push(@extras,
     AUTHOR   => 'Reini Urban <rurban@cpan.org>')
  if $EUMM_VER gt '5.4301';
push(@extras,
    LICENSE => 'perl_5',
    SIGN => 1)
  if $EUMM_VER gt '6.17';
push(@extras,
    'META_MERGE'  => {
      resources =>
      {
       repository  => 'http://github.com/rurban/Perfect-Hash',
       license     => 'http://dev.perl.org/licenses/',
      },
      release_status => 'unstable',
     })
  if $EUMM_VER gt '6.46';

WriteMakefile
  (
   'NAME'	   => 'Perfect::Hash',
   'VERSION_FROM'  => 'lib/Perfect/Hash.pm',
   'ABSTRACT_FROM' => 'lib/Perfect/Hash.pm',
   'PL_FILES'   => { 'script/phash.PL' => 'script/phash' },
   'EXE_FILES'  => [ 'script/phash' ],
   # note that some old buggy EUMM will skip -lz here. 5.8.9 with 6.88 e.g.
   # Warning (mostly harmless): No library found for -lz
   # It is not harmless, see below
   'LIBS'       => [ "-lz" ],
   'PREREQ_PM'	=> {
     'Time::HiRes' => 0,
     #'coretypes' => 0,
   },
   clean => { FILES => "Hash.c.gcov Hash.xs.gcov Hash.gcda Hash.gcno "
                      ."cover_db perf.data script/phash" },
   @extras
  );

# Potentially cleanup a broken ExtUtils::Liblist 6.88, add -lz manually.
# TODO: skip using the XS module if -lz is really not found.
my ($IN, $OUT, $changed, $saw_lz);
open $IN, "<", "Makefile";
open $OUT, ">", "Makefile.tmp";
while (<$IN>) {
  $saw_lz++ if / -lz/;
  unless (/^LDLOADLIBS/) {
    print $OUT $_;
    next;
  }
  if (/ -lz/) { # all ok
    $saw_lz++;
    print $OUT $_;
    next;
  }
  chomp;
  $_ .= " -lz\n";
  print $OUT $_;
  $changed++;
}
close $IN;
close $OUT;
if ($changed) {
  warn "Warning: Patched -lz to LDLOADLIBS\n";
  rename "Makefile.tmp", "Makefile";
} elsif ($saw_lz) {
  unlink "Makefile.tmp";
} else {
  # Missing const_loadlibs section
  warn "Warning: Missing -lz, added -lz to OTHERLDFLAGS manually\n";
  system(qq($^X -pi.tmp -e"s/OTHERLDFLAGS = /OTHERLDFLAGS = -lz /" Makefile));
  unlink "Makefile.tmp";
}

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
testfast :: pure_all
	$(FULLPERLRUN) -S prove -b -j4 -f
test_cover :: pure_all
	$(RM_RF) cover_db
	$(PERLRUNINST) -S cover -test
test_coveralls :: pure_all
	test -f .coveralls.yml && $(PERLRUNINST) -S cover -test -report coveralls
'; }
