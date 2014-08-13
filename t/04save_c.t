#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

#use Config;
use lib 't';
require "test.pl";

my ($default, $methods, $opts) = test_parse_args();

plan tests => 5 * scalar(@$methods);

my $dict = "examples/words500";

# Pearson and PearsonNP do pass/fail randomly
# delete $Perfect::Hash::algo_todo{'-pearson'};

my $i = 0;
for my $m (@$methods) {
  my $ph = new Perfect::Hash($m eq '-pearson8' ? "examples/words20" : $dict, $m, @$opts);
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  if ($m =~ /^-xxcmph/) {
    ok(1, "SKIP nyi save_c for $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  my ($nul) = grep {$_ eq '-nul'} @$opts;
  test_wmain(1, 'AOL', $ph->perfecthash('AOL'), $nul);
  $i++;
  $ph->save_c("phash");
  if (ok(-f "phash.c" && -f "phash.h", "$m generated phash.c/.h")) {
    my $cmd = compile_cmd($ph);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = $^O eq 'MSWin32' ? `phash` : `./phash`;
      $retval = $?;
      TODO: {
        local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
        like($retstr, qr/^ok - c lookup exists/m, "$m c lookup exists");
        like($retstr, qr/^ok - c lookup notexists/m, "$m c lookup notexists");
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
  unlink("phash","phash.c","phash.h","main.c") if $default;
}
