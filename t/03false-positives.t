#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = opt_parse_args();
plan tests => 2*scalar(@$methods);
my ($dict, $dictarr, $size, $custom_size) = opt_dict_size($opts, "examples/words20");
my $small_dict = $size > 255 ? "examples/words20" : $dict;

for my $m (@$methods) {
  my $ph = new Perfect::Hash($m eq '-pearson8' ? $small_dict : $dict, $m, @$opts);
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1, "SKIP");
    next;
  }
  my $w = 'good';
  my $v = $ph->perfecthash($w);
  TODO: {
    local $TODO = "$m" if $m =~ /^-cmph/;
    my $vs = defined $v ? "$v" : 'undef';
    if ($ph->false_positives) {
      # this really should not happen!
      ok(defined($v) && $v >= 0, "method $m without false-positives '$w' => $vs");
    } else {
      is($v, undef, "method $m without false-positives '$w' => $vs");
    }
  }

  my $ph1 = new Perfect::Hash($m eq '-pearson8' ? $small_dict : $dict, $m, @$opts, '-false-positives');
  $v = $ph1->perfecthash($w);
  TODO: {
    local $TODO = "$m" if $m =~ /^(-cmph-.*|-pearson)/;
    my $vs = defined $v ? "$v" : 'undef';
    if ($ph1->false_positives) {
      ok(defined($v) && $v >= 0, "method $m with false_positives '$w' => $vs");
    } else {
      is($v, undef, "method $m without false_positives '$w' => $vs");
    }
  }
}
