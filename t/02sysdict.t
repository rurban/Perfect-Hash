#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

my $dict;
for (qw(/usr/share/dict/words /usr/dict/words /opt/local/share/dict/words)) {
  if (-e $_) { $dict = $_; last }
}
plan skip_all => "no system dict found" unless -e $dict;

my @methods = keys %Perfect::Hash::algo_methods;
plan tests => scalar(@methods);

open my $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

for my $m (map {"-$_"} @methods) {
  diag "generating ph for $dict...";
  my $ph = new Perfect::Hash \@dict, $m;
  diag "done";
  my $ok = 1;
  my $i = 0;
  for my $w (@dict[0..600]) {
    my $v = $ph->perfecthash($w);
    $ok = 0 if $v ne $i;
    unless ($ok) {
      is($v, $i, "method $m for '$w' => $v");
      last;
    }
    $i++;
  }
  $ok ? ok($ok, "checked 600 words of $#dict with method $m") : 0;
}
