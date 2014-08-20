#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = opt_parse_args();
$methods = [ grep(!/^-cmph/, @$methods) ];

plan tests => scalar(@$methods);

my %dict = map {chr $_ => $_-48} (48..64);
delete $dict{'\\'};
for my $m (@$methods) {
  my $ph = new Perfect::Hash \%dict, $m, @$opts;
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
     $ok = 0 if !defined($v) or $v != $o - 48;
     unless ($ok) {
       is(defined($v)?$v:"", $o - 48, "method '$m' for '$w' => ".(defined($v)?$v:""));
       last;
     }
   }
   $ok ? ok($ok, "method '$m'") : 0;
  }
}
