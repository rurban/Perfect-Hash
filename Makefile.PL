use strict;
#use 5.005062;
use ExtUtils::MakeMaker;
use Config;

# TODO: we should provide an option to provide a B::CC compiled script/pperf,
# which would e.g. use faster versions of the pure perl modules.

# TODO try c compiler and extract cmph, nbperf and bob then
#use ExtUtils::Embed;

my ($libs, $incdir, $libdir);
if (!$ENV{PERL_CORE}) {
  $libs = "-lz";
  # try -lz with Devel::CheckLib, and disable Hanov/Urban if failed
  use lib 'inc';
  require Devel::CheckLib;
  Devel::CheckLib->import();
  my $args = join(" ", @ARGV);
  if ($args =~ /INCDIR[ =](\S+)/) {
    $incdir = $1;
  }
  if ($args =~ /LIBDIR[ =](\S+)/) {
    $libdir = $1;
  }
  if ($libdir or $incdir) {
    eval qq/assert_lib( lib => 'z', header => 'zlib.h', libpath => $libdir, incpath => $incdir )/;
  } else {
    eval q/assert_lib( lib => 'z', header => 'zlib.h' )/;
  }
  if ($@) {
    warn "Warning: no zlib found. Disabled Hanov and Urban extensions for crc32()\n";
    $libs = "";
  }
}

# Note: These 2 Makefiles will be overwritten later by recursive WriteMakefile
# So generate all required binaries here
if (! -e "cmph-2.0/configure") {
  print "Extracting cmph-2.0.tar.gz\n";
  my $retval = system("tar xfz cmph-2.0.tar.gz");
  # Win32 MSVC, no tar
  if ($retval>>8 or (! -e "cmph-2.0/configure" and -e "cmph-2.0/Makefile.PL")) {
    chdir "cmph-2.0";
    rename "Makefile.PL", "Makefile_PL.disabled";
    warn "disabled cmph extension\n";
    chdir "..";
  }
}

if (! -e "nbperf/Makefile") {
  if (-d '.git') {
    print "Updating nbperf submodule\n";
    system("git submodule update --init");
  } else {
    print "Cloning git://github.com/rurban/nbperf.git\n";
    system("git clone git://github.com/rurban/nbperf.git");
  }
}

if (! -e "bob/lookupa.c") {
  if (-d '.git') {
    print "Updating bob submodule\n";
    system("git submodule update --init");
  } else {  
    print "Cloning git://github.com/rurban/jenkins-minimal-perfect-hash.git to bob\n";
    system("git clone git://github.com/rurban/jenkins-minimal-perfect-hash.git -b perl bob");
  }
}
# Win32 MSVC, no git
if (!-e "bob/lookupa.c" and -e "bob/Makefile.PL") {
  rename "bob/Makefile.PL", "bob/Makefile_PL.disabled";
}
if (-e "bob/lookupa.c" and !-e "bob/perfect".$Config{exe_ext}) {
  chdir "bob";
  my $cc = $Config{cc};
  my $retval = system($Config{'make'}, "-s", "-f", "Makefile.orig", "CC='$cc'");
  if ($retval>>8) {
    rename "Makefile.PL", "Makefile_PL.disabled";
    warn "disabled bob extension\n";
  }
  chdir "..";
}

if (!-e "nbperf/nbperf".$Config{exe_ext}) {
  chdir "nbperf";
  my $cc = $Config{cc};
  my $retval = system($Config{'make'}, "CC='$cc'");
  if ($retval>>8) {
    warn "disabled nbperf extension\n";
  } else {
    system($Config{'make'}, "install");
  }
  chdir "..";
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

my $pathsep = $^O eq 'MSWin32' ? '\\' : "/";
WriteMakefile
  (
   'NAME'	   => 'Perfect::Hash',
   'VERSION_FROM'  => 'lib'.$pathsep.'Perfect'.$pathsep.'Hash.pm',
   'ABSTRACT_FROM' => 'lib'.$pathsep.'Perfect'.$pathsep.'Hash.pm',
   'PL_FILES'   => { 'script'.$pathsep.'pperf.PL' => 'script'.$pathsep.'pperf' },
   'EXE_FILES'  => [ 'script'.$pathsep.'pperf' ],
   # note that some old buggy EUMM will skip -lz here. 5.8.9 with 6.88 e.g.
   # Warning (mostly harmless): No library found for -lz
   # It is not harmless, see below
   'LIBS'       => [ $libs ],
   'DEFINE'     => $libs ? "-DHAVE_ZLIB" : "",
   'PREREQ_PM'	=> {
     'Time::HiRes' => 0,
     #'coretypes' => 0,
   },
   clean => { FILES => "*.gcov *.gcda *.gcno"
                      ." cover_db perf.data script/pperf"
                      ." pperf* main*"
   },
   @extras
  );

# Potentially cleanup a broken ExtUtils::Liblist 6.88, add -lz manually.
# TODO: skip using the XS module if -lz is really not found.
if ($libs) {
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
testfast :: pure_all README.md
	$(FULLPERLRUN) -S prove -b -j4 -f
test_release :: pure_all README.md
	RELEASE_TESTING=1 $(FULLPERLRUN) -S prove -b -j4
test_cover :: pure_all README.md
	$(RM_RF) cover_db
	$(PERLRUNINST) -S cover -test
test_coveralls :: pure_all
	test -f .coveralls.yml && $(PERLRUNINST) -S cover -test -report coveralls
bench :: pure_all
	examples/all-bench.sh
'; }
