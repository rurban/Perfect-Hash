#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

#my @methods = keys %Perfect::Hash::algo_methods;
my @methods = qw(hanovpp);
plan tests => scalar(@methods) + 1;

my %dict = map {chr $_ => $_-48} (49..125);
for my $m ("", map {"-$_"} @methods) {
  my $ph = new Perfect::Hash \%dict, $m;
  my $ok = 1;
  for my $c (49..125) {
    my $v = $ph->perfecthash(chr $c);
    $ok = 0 if $dict{$v} != $c-48;
    unless ($ok) {
      is($dict{$v}, $c-48, "method $m for '".chr($c)."' => $v");
      last;
    }
  }
  $ok ? ok($ok, "method $m") : 0;
}
