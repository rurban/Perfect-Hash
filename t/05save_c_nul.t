#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = test_parse_args();

plan tests => 5 * scalar(@$methods);

my $dict = "examples/words500";

# Pearson and PearsonNP do pass consistently with -nul, but fail randomly without
delete $Perfect::Hash::algo_todo{'-pearson'};
delete $Perfect::Hash::algo_todo{'-pearsonnp'};

my $i = 0;
my $key = "AOL";
my $suffix = "_nul";

for my $m (@$methods) {
  my $ph = new Perfect::Hash($m eq '-pearson8' ? "examples/words20" : $dict, $m,
                             @$opts, "-nul");
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
  test_wmain(1, $key, $ph->perfecthash($key), $suffix, 1);
  $i++;
  $ph->save_c("phash$suffix");
  if (ok(-f "phash$suffix.c" && -f "phash$suffix.h", "$m generated phash$suffix.c/.h")) {
    my $cmd = compile_cmd($ph, $suffix);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = `./phash$suffix`;
      $retval = $?;
      TODO: {
        local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
        like($retstr, qr/^ok - c lookup exists/m, "$m c lookup exists");
        like($retstr, qr/^ok - c lookup notexists/m, "$m c lookup notexists");
      }
    } else {
      ok(1, "SKIP") for 1..2;
    }
    TODO: {
      local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m}; # will return errcodes
      ok(!($retval>>8), "could run $m");
    }
  } else {
    ok(1, "SKIP") for 1..3;
  }
  unlink("phash$suffix","phash$suffix.c","phash$suffix.h","main$suffix.c") if $default;
}
