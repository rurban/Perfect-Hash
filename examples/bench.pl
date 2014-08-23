#!/usr/bin/perl -w
# pb examples/bench.pl -size 1023 -hanovpp -urban -pearsonnp ...
# TODO: bench against traditional hash tables (linked list, sorted list, double hashing, cuckoo)
use strict;
use Perfect::Hash;
use B ();
use Config;

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = opt_parse_args();
# do not compile files larger than this (in bytes)
# 147.700.000 was generated in 25secs and compiled in 20sec with a run-time of 0.005429
# but 153.000.000 takes extremely long with -O3. -O0 is fine though.
my $max_c_size = 150_000_000;

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
    my $old_custom_size;
    next if $m eq '';
    next if $m eq '-pearson8' and $size > 255;
    next if $m =~ /^-cmph/ and $opt =~ /-false-positives/;
    if ($m eq '-gperf') { # hack to pass an arrayref to -gperf, no file.
      $old_custom_size = $custom_size;
      $custom_size = 1;
    }
    my ($t0, $t1, $t2) = (0.0, 0.0, 0.0);
    $t0 = [gettimeofday];
    my $ph = new Perfect::Hash(
      $custom_size ? \@dict : $dict, $m,
      split(/ /,$opt),
      ($opt =~ /-max-time/ ? () : qw(-max-time 20)));
    $t0 = tv_interval($t0);
    unless ($ph) {
      $i++;
      next;
    }
    if ($m eq '-gperf') {
       $custom_size = $old_custom_size;
    }
    my $suffix = $m eq "-bob" ? "_hash" : "";
    my $base = "phash$suffix";
    my $out = "$base.c";
    # use size/5 random entries
    test_wmain_all($m, \@dict, $opt, $suffix);
    $i++;
    unlink $out;
    my ($cmd, $cmd1);
    if ($opt =~ /-shared/) {
      $cmd = compile_shared($ph, $suffix);
      $cmd1 = link_shared($ph, $suffix);
    } else {
      $cmd = compile_static($ph, $suffix);
    }
    $t1 = [gettimeofday];
    $ph->save_c($base);
    my $retval;
    if (-f $out and -s $out) {
      if (-s $out > $max_c_size) {
        warn "Warning: disabling -O3, $out too large: ",-s $out,"\n";
        $cmd =~ s/-O[23sx]/-O0/g;
        #$retval = -1;
      }
      print "$cmd\n" if $ENV{TEST_VERBOSE};
      $retval = system($cmd); # ($^O eq 'MSWin32' ? "" : " 2>/dev/null"));
      if ($cmd1) {
        print "$cmd1\n" if $ENV{TEST_VERBOSE};
        $retval = system($cmd1); # ($^O eq 'MSWin32' ? "" : " 2>/dev/null"));
      }
    } else {
      $retval = -1;
    }
    $t1 = tv_interval($t1);
    my $s = -s $out;
    my $so = 0;
    if ($retval == 0) {
      $so = $cmd1 ? -s "$base.".$Config{dlext} : -s $base;
      $t2 = [gettimeofday];
      my $callprefix = $^O eq 'MSWin32' ? ""
        : $^O eq 'darwin' ? "DYLD_LIBRARY_PATH=. ./"
        : "LD_LIBRARY_PATH=. ./";
      my $retstr = `${callprefix}$base`;
      $t2 = tv_interval($t2);
      $retval = $? >> 8;
      $t2 = 0 if $retval and $t2 == 0.0;
    }
    printf "%-12s %.06f % .06f %.06f %8d %8d  %s\n",
       $m?substr($m,1):"", $t2, $t0, $t1, $s, $so, $opt;
    if ($retval) {
      print "\t\t\twith ", $retval, " errors.\n";
    }
    unlink("$base","$base.c","$base.h","main.c") if $default;
  }
  print "----\n";
}

