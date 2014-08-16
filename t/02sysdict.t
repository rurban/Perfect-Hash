#!/usr/bin/perl -w
# pure perl only
use Test::More;
use Perfect::Hash;

use lib 't';
require "test.pl";

my $dict;
for (qw(examples/words /usr/share/dict/words /usr/dict/words /opt/local/share/dict/words)) {
  if (-e $_) { $dict = $_; last }
}
plan skip_all => "no system dict found" unless -e $dict;
my ($default, $methods, $opts) = test_parse_args('-max-time',10);
plan tests => scalar(@$methods);

my $d;
open $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

for my $m (@$methods) {
  diag "generating $m ph for ".scalar @dict." entries in $dict..." if $ENV{TEST_VERBOSE};
  my $t0 = [gettimeofday];
  my $ph = new Perfect::Hash $dict, $m, @$opts;
  diag "done in ",tv_interval($t0),"s\n" if $ENV{TEST_VERBOSE};
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    next;
  }
  TODO: {
    local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
    my $ok = 1;
    my $i = 0;
    for my $w (@dict) {
      my $v = $ph->perfecthash($w);
      $ok = 0 if !defined($v) or $v ne $i;
      unless ($ok) {
        is($v, $i, "method $m for $i-th '$w' => ".$v);
        last;
      }
      $i++;
    }
    $ok ? ok($ok, "checked all $#dict words with method $m") : 0;
  }
}
