#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

my @methods = keys %Perfect::Hash::algo_methods;
my %todo = map {$_=>1} qw(-urban -pearsonpp -pearsonnp);
plan tests => 2*(scalar(@methods) + 0);

# test words20 as hashref and arrayref
my $dict = "examples/words20";
open my $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

for my $m (map {"-$_"} @methods) {
  my $ph = new Perfect::Hash \@dict, $m;
  unless ($ph) {
    ok(1, "SKIP empty ph $m");
    ok(1, "SKIP empty ph $m");
    next;
  }
TODO: {
  local $TODO = "$m" if exists $todo{$m};
  my $ok = 1;
  my $i = 0;
  for my $w (@dict) {
    my $v = $ph->perfecthash($w);
    $ok = 0 if $v ne $i;
    unless ($ok) {
      is($v, $i, "method $m with arrayref for '$w' => $v");
      last;
    }
    $i++;
  }
  $ok ? ok($ok, "method $m with arrayref") : 0;
  }
}

my $line = 1;
my %dict = map { $_ => $line++ } @dict;
for my $m (map {"-$_"} @methods) {
  my $ph = new Perfect::Hash \%dict, $m;
TODO: {
  local $TODO = "$m" if exists $todo{$m};
  my $ok = 1;
  for my $w (keys %dict) {
    my $v = $ph->perfecthash($w);
    $ok = 0 if $v ne $dict{$w};
    unless ($ok) {
      is($dict{$w}, $v, "method $m  with hashref for '$w' => $v");
      last;
    }
  }
  $ok ? ok($ok, "method $m with hashref") : 0;
  }
}
