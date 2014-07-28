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

WriteMakefile(
  NAME         => 'Perfect::Hash::CMPH',
  XS           => { 'CMPH.xs' => 'CMPH.c' },
  XSPROTOARG   => '-noprototypes',
  INC          => '-Iinclude',
  LIBS         => '-Llib -lcmph',
  VERSION_FROM => '../lib/Perfect/Hash/CMPH.pm',
  @extras
);

#TODO: integrate into proper build and depend rules
if (grep/--build/,@ARGV) {
  system("./configure --prefix=`pwd`");
  system("make");
  system("make install");
}