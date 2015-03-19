#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use bytes;
use lib 't';
require "test.pl";

my ($default, $methods, $opts) = opt_parse_args('-max-time', 10);

plan tests => 4 * scalar(@$methods);

my ($dict, $dictarr, $size) = opt_dict_size($opts, "examples/utf8");
my @dict = @$dictarr;

# CMPH worked fine for some time
#delete $Perfect::Hash::algo_todo{'-cmph-bdz_ph'};
#delete $Perfect::Hash::algo_todo{'-cmph-bdz'};
#delete $Perfect::Hash::algo_todo{'-cmph-bmz'};
delete $Perfect::Hash::algo_todo{'-cmph-chm'};
#delete $Perfect::Hash::algo_todo{'-cmph-fch'};
#delete $Perfect::Hash::algo_todo{'-cmph-chd_ph'};
#delete $Perfect::Hash::algo_todo{'-cmph-chd'};
$Perfect::Hash::algo_todo{'-bob'} = 1;
$Perfect::Hash::algo_todo{'-pearson16'} = 1;

my @small_dict = @dict[0..200];
my $i = 0;
#my $suffix = "_utf8";

for my $m (@$methods) {
  my $used_dict = $m eq '-pearson8'
    ? \@small_dict
    : $m eq '-gperf'
      ? $dictarr
      : $dict;
  my $ph = new Perfect::Hash($used_dict, $m, @$opts);
  unless ($ph) {
    ok(1, "SKIP empty pperf $m") for 1..4;
    $i++;
    next;
  }
  my $suffix = $m eq "-bob" ? "_hash" : "_utf8";
  my $base = "pperf$suffix";
  test_wmain_all($m, \@dict, $opts, $suffix);
  $i++;
  $ph->save_c($base);
  # utf8 seqs being split on word boundaries with -switch in comments caused
  # emacs display a randomly wrong encoding - mojibake.
  open my $FH, ">>", "$base.c";
  print $FH "/*\nLocal variables:\n  mode: C\n  coding: utf-8-unix\nEnd:\n*/";
  close $FH;
  if (ok(-f "$base.c" && -f "$base.h", "$m generated $base.c/.h")) {
    my $cmd = compile_static($ph, $suffix);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = $^O eq 'MSWin32' ? `$base` : `./$base`;
      $retval = $?;
      TODO: {
        local $TODO = "$m not yet" if exists $Perfect::Hash::algo_todo{$m};
        is($retval>>8, 0, "no c lookup errors $m");
        diag($retstr) if $retval>>8 and $ENV{TEST_VERBOSE};
      }
    } else {
      ok(1, "SKIP !compile");
    }
  TODO: {
    local $TODO = "$m not yet" if exists $Perfect::Hash::algo_todo{$m}; # will return errcodes
    ok(!($retval>>8), "could run $m");
    }
  } else {
    ok(1, "SKIP !save_c") for 1..3;
  }
  unlink("$base","$base.c","$base.h","main$suffix.c") if $default;
}
