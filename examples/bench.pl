#!/usr/bin/perl -w
# pb examples/bench.pl -hanovpp -urban -pearsonnp
use strict;
use Perfect::Hash;
use Config;
use ExtUtils::Embed qw(ccflags ldopts);

my @methods = sort keys %Perfect::Hash::algo_methods;
my @opts = ();
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
  @methods = @m ? @m : grep { $_ = $Perfect::Hash::algo_todo{"-$_"} ? undef : "-$_" } @methods;
} else {
  @methods = grep { $_ = $Perfect::Hash::algo_todo{"-$_"} ? undef : "-$_" } @methods;
  $default = 1;
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

sub compile_cmd {
  my $ph = shift;
  my $opt = $Config{optimize};
  $opt =~ s/-O2/-O3/;
  # TODO: Win32 /Of
  my $cmd = $Config{cc}." -I. $opt ".ccflags
           ." -o phash main.c phash.c ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  $cmd .= $ph->c_lib;
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
  srand(42); # same random dict lookups for all
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

# 0 1 => 0, 1, 0 1
# 0 1 2 => 0, 1, 2, 0 1, 0 2, 1 2, 0 1 2
# 0 1 2 3 => 0, 1, 2, 3, 0 1, 0 2, 1 2, ...
# by Mark Jason Dominus, from List::PowerSet
sub powerset {
  return [[]] if @_ == 0;
  my $first = shift;
  my $pow = &powerset;
  [ map { [$first, @$_ ], [ @$_] } @$pow ];
}

my $i = 0;
print "size=$size, lookups=",int($size/5),"\n";
printf "%-12s %7s %7s %7s\t%s\n", "Method", "generate", "compile", "*lookup*", "options";
# all combinations of save_c inflicting @opts
@opts = qw(-no-false-positives -nul) unless @opts;
for my $opt (@{&powerset(@opts)}) {
  $opt = join(" ", @$opt) if ref $opt eq 'ARRAY';
  my @try_methods = @methods;
  if ($default and $opt =~ /-nul/) {
    push @try_methods, ('-pearson','-pearsonnp');
  }
  for my $m (@try_methods) {
    next if $m eq '-pearson8';
    my ($t0, $t1, $t2) = (0.0, 0.0, 0.0);
    $t0 = [gettimeofday];
    my $ph = new Perfect::Hash \@dict, $m, split(/ /,$opt);
    $t0 = tv_interval($t0);
    unless ($ph) {
      $i++;
      next;
    }
    # use size/5 random entries
    wmain(\@dict, $opt);
    $i++;
    $ph->save_c("phash");
    my $cmd = compile_cmd($ph);
    $t1 = [gettimeofday];
    my $retval = system($cmd." 2>/dev/null");
    $t1 = tv_interval($t1);
    if (!($retval>>8)) {
      $t2 = [gettimeofday];
      my $retstr = `./phash`;
      $t2 = tv_interval($t2);
      $retval = $?;
    }
    printf "%-12s %.06f %.06f %.06g\t%s\n", substr($m,1), $t0, $t1, $t2, $opt;
    if ($retval>>8) {
      print "\t", $retval>>8, " errors\n";
    }
  }
}

unlink("phash","phash.c","phash.h","main.c") unless $default;
