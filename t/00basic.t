#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

my @methods = keys %Perfect::Hash::algo_methods;
my %todo = map {$_=>1} qw(-urban -pearsonpp -pearsonnp -pearson8);
plan tests => scalar(@methods) + 1;

my %dict = map {chr $_ => $_-48} (49..125);
for my $m ("", map {"-$_"} @methods) {
  my $ph = new Perfect::Hash \%dict, $m;
  unless ($ph) {
    ok(1, "SKIP empty ph $m");
    ok(1, "SKIP empty ph $m");
    next;
  }
TODO: {
  local $TODO = "$m" if exists $todo{$m};
  my $ok = 1;
  for my $c (49..125) {
    my $w = chr $c;
    my $v = $ph->perfecthash($w);
    $ok = 0 if $v != $c-48;
    unless ($ok) {
      is($v, $c-48, "method '$m' for '$w' => $v");
      last;
    }
  }
  $ok ? ok($ok, "method '$m'") : 0;
  }
}
