#! perl
use Config;
use File::Basename qw(&basename &dirname);
use File::Spec;
use Cwd;

# List explicitly here the variables you want Configure to
# generate.  Metaconfig only looks for shell variables, so you
# have to mention them as if they were shell variables, not
# %Config entries.  Thus you write
#  $startperl
# to ensure Configure will look for $Config{startperl}.
# Wanted:  $archlibexp

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
$origdir = cwd;
chdir dirname($0);
$file = basename($0, '.PL');
$file .= '.com' if $^O eq 'VMS';

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

# In this section, perl variables will be expanded during extraction.
# You can use $Config{...} to use Configure variables.

print OUT <<"!GROK!THIS!";
$Config{startperl}
    eval 'exec $Config{perlpath} -S \$0 \${1+"\$@"}'
    if \$running_under_some_shell;
--\$running_under_some_shell;
!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';
use Perfect::Hash;
use Getopt::Long;
use Pod::Usage;
my $options = {};

sub opt(*) {
  my $opt = shift;
  return exists($options->{$opt}) && ($options->{$opt} || 0);
}

sub version {
  no warnings 'once';
  return "phash $Perfect::Hash::VERSION\n";
}

sub _usage_and_die {
  print <<'EOF';
Usage:
phash [method] [options...] keyfile

Methods:
--hanovpp
--urban
--pearsonnp

Options:
--no-false-positives
--nul
--for-c

Planned:
--minimal
--optimal-size
--optimal-speed
--for-c
--for-xs
--hash=name
--pic
--null-strings
--7bit
--ignore-case
--unicode-ignore-case

EOF
  exit;
}

sub helpme {
  print version(),"\n";
  if (opt('v')) {
    pod2usage( -verbose => opt('v') );
  } else {
    pod2usage( -verbose => 0 );
  }
  _usage_and_die;
}

GetOptions
  ($options,
   'help|h',
   'hanovpp',
   'urban',
   'pearson',
   'pearson8',
   'pearsonnp',
   'false-positives!',
   'nul',
   '7bit',
   'prefix=s',
   'for-c!',
   'ignore-case',
   'unicode-ignore-case',
   'optimal-speed',
   'optimal-size',
   'minimal',
  );
helpme() if opt('help'); # And exit
my $keyfile = shift or _usage_and_die();
my @options = map { ("-".$_, $options->{$_} == 1 ? () : $options->{$_}) } keys %$options;

my $ph = new Perfect::Hash $keyfile, @options;
# TODO: check for other output formatters and load it.
if ($options->{'for-xs'}) {
  $ph->save_xs($options->{prefix});
} else {
  $ph->save_c($options->{prefix});
}

!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
chdir $origdir;

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 2
#   fill-column: 80
# End:
# vim: expandtab shiftwidth=2:
