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
#delete $Perfect::Hash::algo_todo{'-cmph-chm'};
#delete $Perfect::Hash::algo_todo{'-cmph-fch'};
#delete $Perfect::Hash::algo_todo{'-cmph-chd_ph'};
#delete $Perfect::Hash::algo_todo{'-cmph-chd'};

my @small_dict = @dict[0..200];
my $i = 0;
my $suffix = "_utf8";

for my $m (@$methods) {
  my $ph = new Perfect::Hash($m eq '-pearson8' ? \@small_dict : \@dict,
                             $m, @$opts);
  unless ($ph) {
    ok(1, "SKIP empty phash $m") for 1..4;
    $i++;
    next;
  }
  my ($nul) = grep {$_ eq '-nul'} @$opts;
  test_wmain_all(\@dict, $opts, $suffix);
  $i++;
  $ph->save_c("phash$suffix");
  # utf8 seqs being split on word boundaries with -switch in comments caused
  # emacs display a randomly wrong encoding - mojibake.
  open my $FH, ">>", "phash$suffix.c";
  print $FH "/*\nLocal variables:\n  mode: C\n  coding: utf-8-unix\nEnd:\n*/";
  close $FH;
  if (ok(-f "phash$suffix.c" && -f "phash$suffix.h", "$m generated phash$suffix.c/.h")) {
    my $cmd = compile_cmd($ph, $suffix);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    TODO: {
      local $TODO = "$m not yet" if $m eq '-gperf';
      if (ok(!($retval>>8), "could compile $m")) {
        my $retstr = $^O eq 'MSWin32' ? `phash$suffix` : `./phash$suffix`;
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
    }
  } else {
    ok(1, "SKIP !save_c") for 1..3;
  }
  unlink("phash$suffix","phash$suffix.c","phash$suffix.h","main$suffix.c") if $default;
}
