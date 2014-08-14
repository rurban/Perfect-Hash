#!/usr/bin/perl -w
# pb examples/bench.pl -hanovpp -urban -pearsonnp ...
# TODO: bench against traditional hash tables (linked list, double hashing, cuckoo)
use strict;
use Perfect::Hash;
use B ();

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = test_parse_args();

if ($default) {
  delete $Perfect::Hash::algo_todo{'-urban'};
  #my @methods = grep { $_ = $Perfect::Hash::algo_todo{$_} ? undef : $_ } @$methods;
  #$methods = \@methods;
}

my ($dict, @dict);
for (qw(examples/words /usr/share/dict/words /usr/dict/words)) {
  if (-e $_) { $dict = $_; last }
}

open my $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;
my $size = scalar @dict;

sub wmain {
  my $dict = $_[0];
  my $opt = $_[1];
  my $FH;
  # we need a main
  open $FH, ">", "main.c";
  if ($opt =~ /-nul/) {
    print $FH '#include <string.h>';
  }
  print $FH '
#include <stdio.h>
#include "phash.h"

static const char *testkeys[] = {
  ';
  my $size = int(scalar(@$dict) / 5);
  srand(42); # same random dict lookups for all, with some utf8 keys
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
    if (h<0) err++;';
  print $FH '
    if (i != h) err++;' if $opt !~ /-false-positives/;
  print $FH '
  }
  return err;
}
';
  close $FH;
}

# 0 1 => 0, 1, 0 1
# 0 1 2 => 0, 1, 2, 0 1, 0 2, 1 2, 0 1 2
# 0 1 2 3 => 0, 1, 2, 3, 0 1, 0 2, 1 2, ...
# by Mark Jason Dominus, from List::PowerSet
sub powerset {
  return [[]] if @_ == 0;
  my $first = shift;
  my $pow = &powerset;
  return [ map { [$first, @$_ ], [ @$_] } @$pow ];
}

my $i = 0;
print "size=$size, lookups=",int($size/5),"  (smaller sec and size is better)\n";
printf "%-12s %8s %9s %7s %8s  %8s  %s\n",
       "Method", "*lookup*", "generate", "compile", "c size", "exesize", "options";
# all combinations of save_c inflicting @opts
$opts = [qw(-false-positives -nul)] unless @$opts;
for my $opt (@{&powerset(@$opts)}) {
  $opt = join(" ", @$opt) if ref $opt eq 'ARRAY';
  my @try_methods = @$methods;
  #if ($default and $opt =~ /-nul/) {
  #  push @try_methods, ('-pearson','-pearsonnp');
  #}
  for my $m (@try_methods) {
    next if $m eq '';
    next if $m eq '-pearson8';
    #next if $m =~ /-pearson/;
    next if $m =~ /^-cmph/ and $opt =~ /-false-positives/;
    my ($t0, $t1, $t2) = (0.0, 0.0, 0.0);
    $t0 = [gettimeofday];
    my $ph = new Perfect::Hash $dict, $m, split(/ /,$opt);
    $t0 = tv_interval($t0);
    unless ($ph) {
      $i++;
      next;
    }
    # use size/5 random entries
    wmain(\@dict, $opt);
    $i++;
    my $cmd = compile_cmd($ph);
    $t1 = [gettimeofday];
    $ph->save_c("phash");
    print "$cmd\n" if $ENV{TEST_VERBOSE};
    my $retval = system($cmd.($^O eq 'MSWin32' ? "" : " 2>/dev/null"));
    $t1 = tv_interval($t1);
    my $s = -s "phash.c";
    my $so = 0;
    if (!($retval>>8)) {
      $so = -s "phash";
      $t2 = [gettimeofday];
      my $retstr = $^O eq 'MSWin32' ? `phash` : `./phash`;
      $t2 = tv_interval($t2);
      $retval = $?;
    }
    printf "%-12s %.06f % .06f %.06f %8d %8d  %s\n",
       $m?substr($m,1):"", $t2, $t0, $t1, $s, $so, $opt;
    if ($retval>>8) {
      print "\t\t\twith ", $retval>>8, " errors.\n";
    }
  }
  print "----\n";
}

unlink("phash","phash.c","phash.h","main.c") if $default;
