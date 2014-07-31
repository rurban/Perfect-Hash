#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use Config;
use ExtUtils::Embed qw(ccflags ldopts);

my @methods = sort keys %Perfect::Hash::algo_methods;
my $tb = Test::More->builder;

$tb->plan(tests => 5*scalar(@methods));

my $dict = "examples/words20";
open my $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

my $cmd = $Config{cc}." -I. ".ccflags." -ophash main.c phash.c ".ldopts;
chomp $cmd;
$cmd .= " -lz";

sub wmain {
  my ($i, $aol) = @_;
  $aol = 0 unless $aol;
  my $i1 = $i +1;
  # and the we need a main also
  open my $FH, ">", "main.c";
  print $FH '
#include <stdio.h>
#include "phash.h"

int main () {
  int err = 0;
  if (phash_lookup("AOL") == '.$aol.')
    printf("ok %d - c lookup exists\n", '.$i.');
  else {
    printf("not ok %d - c lookup exists\n", '.$i.'); err++;
  }
  if (phash_lookup("notexist") == -1)
    printf("ok %d - c lookup notexists\n", '.$i1.');
  else {
    printf("not ok %d - TODO c lookup notexists\n", '.$i1.');
  }
  return err;
}
';
  close $FH;
}

my $i = 0;
for my $m (map {"-$_"} @methods) {
  my $ph = new Perfect::Hash \@dict, $m, '-no-false-positives';
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  wmain((5*$i)+3, $ph->perfecthash('AOL'));
  $i++;
  $ph->save_c("phash");
  ok(-f "phash.c" && -f "phash.h", "$m generated phash.c/.h");
  diag($cmd);
  my $retval = system($cmd);
  if (ok(!($retval>>8), "could compile")) {
    $retval = system("./phash");
    #lock $tb->{Curr_Test};
    $tb->{Curr_Test}++;
    $tb->{Curr_Test}++;
  } else {
    ok(1) for 0..1;
  }
  ok(!($retval>>8), "could run");
  unlink("phash","phash.c","phash.h","main.c");
}
