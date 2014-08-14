# library of Perfect::Hash test functions

use strict;
use Config;
use ExtUtils::Embed qw(ccflags ldopts);
use B ();

# usage: my ($default, $methods, $opts) = parse_args(@default_opts);
sub test_parse_args {
  my @opts = @_;
  my @methods = map {s/::/-/g; lc $_} @Perfect::Hash::algos;
  my $default;
  if (@ARGV and grep /^-/, @ARGV) {
    my @m = ();
    for (@ARGV) {
      my ($m) = /^-(.*)/;
      if (exists $Perfect::Hash::algo_methods{$m}) {
        push @m, $_;
      } else {
        push @opts, $_;
      }
    }
    @methods = @m if @m;
  } else {
    $default = 1;
    @methods = ('', map {"-$_"} @methods);
  }
  return ($default, \@methods, \@opts);
}

sub compile_cmd {
  my $ph = shift;
  my $suffix = shift || "";
  my $opt = $Config{optimize};
  $opt =~ s/-O[xs12]/-O3/;
  my $cmd = $Config{cc}.$ph->c_include()." -I. $opt ".ccflags
           ." -o phash$suffix main$suffix.c phash$suffix.c ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  if ($^O eq 'MSWin32' and $Config{cc} =~ /cl/) {
    $cmd =~ s/-o phash$suffix/-nologo -Fe phash$suffix.exe/;
  }
  $cmd .= $ph->c_lib();
  return $cmd;
}

sub test_wmain {
  my ($fp, $key, $value, $suffix, $nul) = @_;
  use bytes;
  $value = 0 unless $value;
  $suffix = "" unless $suffix;
  my $FH;
  # and then we need a main also
  open $FH, ">", "main$suffix.c";
  print $FH "
#include <stdio.h>
#include \"phash$suffix.h\"

int main () {
  int err = 0;
  long v = phash$suffix\_lookup(\"$key\"" . ($nul ? ', '.length($key) : "") . ");
  if (v == $value) {
    printf(\"ok - c lookup exists %ld\\n\", v);
  } else {
    printf(\"not ok - c lookup exists %ld\\n\", v); err++;
  }";
  unless ($fp) {
    print $FH "
  return err;
}
";
    close $FH;
    return;
  }
  print $FH "
  if ((v = phash$suffix\_lookup(\"notexist\"" . ($nul ? ", 8" : "") . ")) == -1) {
    printf(\"ok - c lookup notexists %ld\\n\", v);
  } else {
    printf(\"not ok - c lookup notexists %ld\\n\", v); err++;
  }
  return err;
}
";
  close $FH;
}

1;
