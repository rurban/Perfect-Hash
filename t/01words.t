#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use lib 't';
require "test.pl";

my ($default, $methods, $opts) = test_parse_args();

plan tests => 3 * scalar(@$methods);

# as hashref and arrayref and file, without utf8 chars
# TODO: use a real gperf compat keyfile here and _dict_init it
my $dict = "examples/words20";
my $d;
open $d, $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;

for my $m (@$methods) {
  my $ph = new Perfect::Hash \@dict, $m, @$opts;
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    next;
  }
 TODO: {
   local $TODO = "$m pure-perl" if exists $Perfect::Hash::algo_todo{$m};
   my $ok = 1;
   my $i = 0;
   for my $w (@dict) {
     my $v = $ph->perfecthash($w);
     $ok = 0 if !defined($v) or $v ne $i;
     unless ($ok) {
       is(defined($v)?$v:"", $i, "method $m with arrayref for '$w' => ".(defined($v)?$v:""));
       last;
     }
     $i++;
   }
   $ok ? ok($ok, "method $m with arrayref") : 0;
  }
}

my $line = 0;
my %dict = map { $_ => $line++ } @dict;
for my $m (@$methods) {
  my $ph = new Perfect::Hash \%dict, $m, @$opts;
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    next;
  }
 TODO: {
   local $TODO = "$m pure-perl" if exists $Perfect::Hash::algo_todo{$m};
   my $ok = 1;
   for my $w (sort keys %dict) {
     my $v = $ph->perfecthash($w);
     $ok = 0 if !defined($v) or $v ne $dict{$w};
     unless ($ok) {
       is(defined($v)?$v:"", $dict{$w}, "method $m with hashref for '$w' => ".(defined($v)?$v:""));
       last;
     }
   }
   $ok ? ok($ok, "method $m with hashref") : 0;
  }
}

for my $m (@$methods) {
  my $ph = new Perfect::Hash $dict, $m, @$opts;
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    next;
  }
 TODO: {
   local $TODO = "$m pure-perl" if exists $Perfect::Hash::algo_todo{$m};
   my $ok = 1;
   my $i = 0;
   for my $w (@dict) {
     my $v = $ph->perfecthash($w);
     $ok = 0 if !defined($v) or $v ne $i;
     unless ($ok) {
       is(defined($v)?$v:"", $i, "method $m with keyfile for '$w' => ".(defined($v)?$v:""));
       last;
     }
     $i++;
   }
   $ok ? ok($ok, "method $m with keyfile") : 0;
  }
}
