#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

my @methods = sort keys %Perfect::Hash::algo_methods;
if (@ARGV and grep /^-/, @ARGV) {
  @methods = grep { $_ = $1 if /^-(.*)/ } @ARGV;
}
plan tests => scalar(@methods) + 1;

my %dict = map {chr $_ => $_-48} (48..125);
delete $dict{'\\'};
for my $m ("", map {"-$_"} @methods) {
  my $ph = new Perfect::Hash \%dict, $m;
  unless ($ph) {
    ok(1, "SKIP empty ph $m");
    next;
  }
 TODO: {
   local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
   my $ok = 1;
   for my $w (sort keys %dict) {
     my $o = ord $w;
     my $v = $ph->perfecthash($w);
     $ok = 0 if $v != $o - 48;
     unless ($ok) {
       is($v, $o - 48, "method '$m' for '$w' => $v");
       last;
     }
   }
   $ok ? ok($ok, "method '$m'") : 0;
  }
}
