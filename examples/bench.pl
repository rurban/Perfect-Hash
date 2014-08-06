#!/usr/bin/perl -w
# pb examples/bench.pl -hanovpp -urban -pearsonnp

use Perfect::Hash;
use Config;
use ExtUtils::Embed qw(ccflags ldopts);

my @methods = sort keys %Perfect::Hash::algo_methods;
my @opts = ();
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
  @methods = map {"-$_"} @methods;
}

my ($dict, @dict);
for (qw(/usr/share/dict/words /usr/dict/words /opt/local/share/dict/words)) {
  if (-e $_) { $dict = $_; last }
}

open my $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;
my $size = scalar @dict;

sub cmd {
  my $m = shift;
  # TODO: Win32 /Of
  my $cmd = $Config{cc}." -I. ".ccflags." -ophash main.c phash.c ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  $cmd .= " -lz" if $m eq '-urban';
  return $cmd;
}

use B;

sub wmain {
  my $dict = $_[0];
  my $opt = $_[1];
  # we need a main
  open my $FH, ">", "main.c";
  print $FH '#include <stdio.h>
#include "phash.h"

static const char const* testkeys[] = {
  ';
  my $size = int(scalar(@$dict) / 5);
  for (0..$size) {
    my $i = int(rand($size));
    print $FH B::cstring($dict->[$i]),", ";
    print $FH "\n  " unless $_ % 8;
  }
  print $FH '
};

int main () {
  int i;
  int err = 0;
  for (i=0; i < ',$size,'; i++) {
    long h = phash_lookup(testkeys[i]';
  if ($opt =~ /-nul/) {
    print $FH ', strlen(testkeys[i])';
  }
  print $FH ');
    if (h<0) err++;
  }
  return err;
}
';
  close $FH;
}

my $i = 0;
print "size=$size, lookups=",int($size/5),"\n";
for my $m (@methods) {
  for my $opt (#"-no-false-positives -nul -7bit",
               "-no-false-positives -nul",
               #"-no-false-positives -7bit",
               "-no-false-positives",
               #"-nul -7bit",
               "-nul",
               #"-7bit",
               "")
  {
    my $t0 = [gettimeofday];
    my $ph = new Perfect::Hash \@dict, $m, split(/ /,$opt);
    print "$m generated in ",tv_interval($t0)," with $opt\n";
    unless ($ph) {
      $i++;
      next;
    }
    # use size/5 random entries
    wmain(\@dict, $opt);
    $i++;
    $ph->save_c("phash");
    #ok(-f "phash.c" && -f "phash.h", "$m generated phash.c/.h");
    my $cmd = cmd($m);
    #diag($cmd);
    $t0 = [gettimeofday];
    my $retval = system($cmd." 2>/dev/null");
    print "$m compiled in ",tv_interval($t0),"\n";
    if (!($retval>>8)) {
      my $t1 = [gettimeofday];
      my $retstr = `./phash`;
      print "$m lookups in ",tv_interval($t0)," with $opt\n";
      $retval = $?;
      if ($retval>>8) {
        print $retval>>8, " errors\n";
      }
    }
  }
}

unlink("phash","phash.c","phash.h","main.c");
