#!/usr/bin/perl -w
# pure perl only
use Test::More;
use Perfect::Hash;

use lib 't';
require "test.pl";

my ($dict, $dictarr, $size, $custom_size);
for (qw(examples/words /usr/share/dict/words /usr/dict/words /opt/local/share/dict/words)) {
  if (-e $_) { $dict = $_; last }
}
plan skip_all => "no system dict found" unless -e $dict;

my ($default, $methods, $opts) = opt_parse_args('-max-time',10);
$methods = [''] if $default;
plan tests => scalar(@$methods);
($dict, $dictarr, $size, $custom_size) = opt_dict_size($opts, $dict);

for my $m (@$methods) {
  diag "generating $m ph for $size entries in $dict..." if $ENV{TEST_VERBOSE};
  my $t0 = [gettimeofday];
  my $ph = new Perfect::Hash $dict, $m, @$opts;
  diag "done in ",tv_interval($t0),"s\n" if $ENV{TEST_VERBOSE};
  unless ($ph) {
    ok(1, "SKIP empty pperf $m");
    next;
  }
  TODO: {
    local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
    my $ok = 1;
    my $i = 0;
    for my $w (@$dictarr) {
      my $v = $ph->perfecthash($w);
      $ok = 0 if !defined($v) or $v ne $i;
      unless ($ok) {
        is($v, $i, "method $m for $i-th '$w' => ".$v);
        last;
      }
      $i++;
    }
    $ok ? ok($ok, "checked all $size words with method $m") : 0;
  }
}
