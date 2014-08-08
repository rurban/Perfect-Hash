#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use Config;
use ExtUtils::Embed qw(ccflags ldopts);

my @methods = sort keys %Perfect::Hash::algo_methods;
my @opts = ('-no-false-positives');
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

plan tests => 5*scalar(@methods);

my $dict = "examples/words20";
my $d;
open $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

sub cmd {
  my $m = shift;
  my $opt = $Config{optimize};
  $opt =~ s/-O2/-O3/;
  # TODO: Win32 /Of
  my $cmd = $Config{cc}." -I. $opt ".ccflags
           ." -ophash main.c phash.c ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  $cmd .= " -lz" if $m eq '-urban' or $m eq '-hanov';
  return $cmd;
}

sub wmain {
  my ($i, $aol, $nul) = @_;
  $aol = 0 unless $aol;
  my $i1 = $i +1;
  # and then we need a main also
  open my $FH, ">", "main.c";
  print $FH '
#include <stdio.h>
#include "phash.h"

int main () {
  int err = 0;
  long h = phash_lookup("AOL"';
  print $FH ', 3' if $nul;
  print $FH ');
  if (h == '.$aol.') {
    printf("ok %d - c lookup exists %d\n", '.$i.', h);
  } else {
    printf("not ok %d - c lookup exists %d\n", '.$i.', h); err++;
  }
  if ((h = phash_lookup("notexist"';
  print $FH ', 7' if $nul;
  print $FH ')) == -1) {
    printf("ok %d - c lookup notexists %d\n", '.$i1.', h);
  } else {
    printf("not ok %d - c lookup notexists %d\n", '.$i1.', h); err++;
  }
  return err;
}
';
  close $FH;
}

# Pearson and PearsonNP do pass/fail randomly
# delete $Perfect::Hash::algo_todo{'-pearson'};

my $i = 0;
for my $m (@methods) {
  my $ph = new Perfect::Hash \@dict, $m, @opts;
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  if ($m =~ /^-cmph/) {
    ok(1, "SKIP nyi save_c for $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  my ($nul) = grep {$_ eq '-nul'} @opts;
  wmain((5*$i)+3, $ph->perfecthash('AOL'), $nul);
  $i++;
  $ph->save_c("phash");
  if (ok(-f "phash.c" && -f "phash.h", "$m generated phash.c/.h")) {
    my $cmd = cmd($m);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = `./phash`;
      $retval = $?;
      TODO: {
        local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
        like($retstr, qr/^ok \d+ - c lookup exists/m, "$m c lookup exists");
        like($retstr, qr/^ok \d+ - c lookup notexists/m, "$m c lookup notexists");
      }
    } else {
      ok(1, "SKIP") for 0..1;
    }
    TODO: {
      local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m}; # will return errcodes
      ok(!($retval>>8), "could run $m");
    }
  } else {
    ok(1, "SKIP") for 0..3;
  }
  unlink("phash","phash.c","phash.h","main.c");
}
