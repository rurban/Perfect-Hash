#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

my $dict;
for (qw(/usr/share/dict/words /usr/dict/words /opt/local/share/dict/words)) {
  if (-e $_) { $dict = $_; last }
}
plan skip_all => "no system dict found" unless -e $dict;

my @methods = sort keys %Perfect::Hash::algo_methods;
my @opts = ();
if (@ARGV and grep /^-/, @ARGV) {
  my @m = ();
  for (@ARGV) {
    my ($m) = /^-(.*)/;
    if (exists $Perfect::Hash::algo_methods{$m}) {
      push @m, $_;
    } else {
      push @opts, $_;
    }
  }
  @methods = @m if @m;
} else {
  @methods = map {"-$_"} @methods;
}
plan tests => scalar(@methods);

my $d;
open $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

# Urban still fails with 32bit keys
$Perfect::Hash::algo_todo{'-urban'} = 1;
# but PearsonNP passes
delete $Perfect::Hash::algo_todo{'-pearsonnp'};

for my $m (@methods) {
  diag "generating $m ph for ".scalar @dict." entries in $dict..." if $ENV{TEST_VERBOSE};
  my $t0 = [gettimeofday];
  my $ph = new Perfect::Hash \@dict, $m, qw(-max-time 10), @opts;
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
    $ok = 0 if $v ne $i;
    unless ($ok) {
      is($v, $i, "method $m for '$w' => $v");
      last;
    }
    $i++;
  }
  $ok ? ok($ok, "checked all $#dict words with method $m") : 0;
  }
}
