use ExtUtils::MakeMaker;
use Config;

my @extras = ();
my $EUMM_VER = $ExtUtils::MakeMaker::VERSION;
push(@extras, CAPI => 'TRUE')
  if (($PERL_VERSION >= 5.005) and ($OSNAME eq 'MSWin32')
      and ($Config{archname} =~ /-object\b/i));

push(@extras,
     ABSTRACT => "XS interface to cmph",
     AUTHOR   => 'Reini Urban <rurban@cpan.org>')
  if $EUMM_VER gt '5.4301';
push(@extras,
     META_MERGE => {
       license => [ 'mozilla_1_1', 'lgpl_2_1' ]
     })
  if $EUMM_VER gt '6.46';

#TODO: integrate into proper build and depend rules
if (! -e "bin/cmph".$Config{exe_ext}) {
  print "building cmph-2.0\n";
  system("autoreconf -i");
  system("./configure --prefix=`pwd`");
  system($Config{'make'}, "-s");
  system($Config{'make'}, "-s", "install");
  rename "Makefile", "Makefile.orig";
}

WriteMakefile(
  NAME         => 'Perfect::Hash::CMPH',
  XS           => { 'CMPH.xs' => 'CMPH.c' },
  XSPROTOARG   => '-noprototypes',
  INC          => '-Iinclude',
  LIBS         => '-Llib -lcmph',
  VERSION_FROM => '../lib/Perfect/Hash/CMPH.pm',
  clean => { FILES => "*.gcov *.gcda *.gcno" },
  @extras
);

