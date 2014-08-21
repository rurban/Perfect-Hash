#!/usr/bin/perl -w
# pb examples/bench.pl -size 1023 -hanovpp -urban -pearsonnp ...
# TODO: bench against traditional hash tables (linked list, sorted list, double hashing, cuckoo)
use strict;
use Perfect::Hash;
use B ();

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = opt_parse_args();
if ($default) { # -urban fixed with 6b1a94e46f893b
  push @$methods, "-switch";
}

my ($dict, @dict, $dictarr, $size, $custom_size);
for (qw(examples/words /usr/share/dict/words /usr/dict/words)) {
  if (-e $_) { $dict = $_; last }
}

($dict, $dictarr, $size, $custom_size) = opt_dict_size($opts, $dict);
@dict = @$dictarr;

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
print "size=$size  (smaller sec and size is better)\n";
printf "%-12s %8s %9s %7s %8s  %8s  %s\n",
       "Method", "*lookup*", "generate", "compile", "c size", "exesize", "options";
# all combinations of save_c inflicting @opts:
$opts = [qw(-false-positives -nul)] unless @$opts;
my @opts = @{&powerset(@$opts)};
@opts = (join " ",@$opts) if grep /-1opt/, @$opts;
for my $opt (@opts) {
  $opt = join(" ", @$opt) if ref $opt eq 'ARRAY';
  my @try_methods = @$methods;
  for my $m (@try_methods) {
    next if $m eq '';
    next if $m eq '-pearson8' and $size > 255;
    next if $m =~ /^-cmph/ and $opt =~ /-false-positives/;
    my ($t0, $t1, $t2) = (0.0, 0.0, 0.0);
    $t0 = [gettimeofday];
    my $ph = new Perfect::Hash($custom_size ? \@dict : $dict, $m, split(/ /,$opt));
    $t0 = tv_interval($t0);
    unless ($ph) {
      $i++;
      next;
    }
    # use size/5 random entries
    test_wmain_all($m, \@dict, $opt);
    $i++;
    my $cmd = compile_cmd($ph);
    my $out = "phash.c";
    unlink $out;
    $t1 = [gettimeofday];
    $ph->save_c("phash");
    my $retval;
    if (-f $out and -s $out) {
      print "$cmd\n" if $ENV{TEST_VERBOSE};
      $retval = system($cmd); # ($^O eq 'MSWin32' ? "" : " 2>/dev/null"));
    } else {
      $retval = -1;
    }
    $t1 = tv_interval($t1);
    my $s = -s $out;
    my $so = 0;
    if ($retval == 0) {
      $so = -s "phash";
      $t2 = [gettimeofday];
      my $retstr = $^O eq 'MSWin32' ? `phash` : `./phash`;
      $t2 = tv_interval($t2);
      $retval = $? >> 8;
    }
    printf "%-12s %.06f % .06f %.06f %8d %8d  %s\n",
       $m?substr($m,1):"", $t2, $t0, $t1, $s, $so, $opt;
    if ($retval>>8) {
      print "\t\t\twith ", $retval, " errors.\n";
    }
  }
  print "----\n";
}

unlink("phash","phash.c","phash.h","main.c") if $default;
