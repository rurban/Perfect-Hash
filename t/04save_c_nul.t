#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use Config;
use ExtUtils::Embed qw(ccflags ldopts);

my @methods = sort keys %Perfect::Hash::algo_methods;
my @opts = ('-nul');
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

plan tests => 4*scalar(@methods);

my $dict = "examples/words20";
my $d;
open $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

sub compile_cmd {
  my $ph = shift;
  my $opt = $Config{optimize};
  $opt =~ s/-O2/-O3/;
  # TODO: Win32 /Of
  my $cmd = $Config{cc}." -I. $opt ".ccflags
           ." -o phash_nul main_nul.c phash_nul.c ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  $cmd .= $ph->c_lib;
  return $cmd;
}

sub wmain {
  my ($i, $aol) = @_;
  $aol = 0 unless $aol;
  my $i1 = $i +1;
  # and then we need a main also
  open my $FH, ">", "main_nul.c";
  print $FH '
#include <stdio.h>
#include "phash_nul.h"

int main () {
  int err = 0;
  long h = phash_nul_lookup("AOL", 3);
  if (h == '.$aol.') {
    printf("ok %d - c lookup exists %ld\n", '.$i.', h);
  } else {
    printf("not ok %d - c lookup exists %ld\n", '.$i.', h); err++;
  }
  return err;
}
';
  close $FH;
}

# Pearson and PearsonNP do pass consistently with -nul, but fail randomly without
delete $Perfect::Hash::algo_todo{'-pearson'};
delete $Perfect::Hash::algo_todo{'-pearsonnp'};

my $i = 0;
for my $m (@methods) {
  my $ph = new Perfect::Hash \@dict, $m, @opts;
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1) for 1..3;
    $i++;
    next;
  }
  if ($m =~ /^-cmph/) {
    ok(1, "SKIP nyi save_c for $m");
    ok(1) for 1..3;
    $i++;
    next;
  }
  wmain((4*$i)+3, $ph->perfecthash('AOL'));
  $i++;
  $ph->save_c("phash_nul");
  if (ok(-f "phash_nul.c" && -f "phash_nul.h", "$m generated phash_nul.c/.h")) {
    my $cmd = compile_cmd($ph);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = `./phash_nul`;
      $retval = $?;
      TODO: {
        local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
        like($retstr, qr/^ok \d+ - c lookup exists/m, "$m c lookup exists");
      }
    } else {
      ok(1, "SKIP");
    }
    TODO: {
      local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m}; # will return errcodes
      ok(!($retval>>8), "could run $m");
    }
  } else {
    ok(1, "SKIP") for 0..2;
  }
  unlink("phash_nul","phash_nul.c","phash_nul.h","main_nul.c");
}
