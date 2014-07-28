use ExtUtils::MakeMaker;
use Config;

my @extras = ();
push(@extras, CAPI => 'TRUE')
    if (($PERL_VERSION >= 5.005) and ($OSNAME eq 'MSWin32')
        and ($Config{archname} =~ /-object\b/i));

push(@extras,
    ABSTRACT => "XS interface to cmph",
    AUTHOR   => 'Reini Urban')
  if ($ExtUtils::MakeMaker::VERSION >= 5.4301);

#TODO: integrate into proper build and depend rules
if (! -e "bin/cmph") {
  system("./configure --prefix=`pwd`");
  system($Config{'make'}, "-s");
  system($Config{'make'}, "-s", "install");
}

WriteMakefile(
  NAME         => 'Perfect::Hash::CMPH',
  XS           => { 'CMPH.xs' => 'CMPH.c' },
  XSPROTOARG   => '-noprototypes',
  INC          => '-Iinclude',
  LIBS         => '-Llib -lcmph',
  VERSION_FROM => '../lib/Perfect/Hash/CMPH.pm',
  @extras
);

