#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

my @methods = sort keys %Perfect::Hash::algo_methods;
plan tests => 2*scalar(@methods);

my $dict = "examples/words20";
for my $m (map {"-$_"} @methods) {
  my $ph = new Perfect::Hash $dict, $m;
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1, "SKIP");
    next;
  }
  my $w = 'good';
  my $v = $ph->perfecthash($w);
  TODO: {
    local $TODO = "$m" if $m =~ /^-cmph/;
    if ($ph->false_positives) {
      # this really should not happen!
      ok($v >= 0, "method $m without false-positives '$w' => $v");
    } else {
      ok(!defined $v, "method $m without false-positives '$w' => undef");
    }
  }

  my $ph1 = new Perfect::Hash $dict, $m, '-false-positives';
  $v = $ph1->perfecthash($w);
  TODO: {
    local $TODO = "$m" if $m =~ /^-cmph/;
    if ($ph1->false_positives) {
      ok($v >= 0, "method $m with false_positives '$w' => $v");
    } else {
      ok(!defined $v, "method $m without false_positives '$w' => $v");
    }
  }
}
