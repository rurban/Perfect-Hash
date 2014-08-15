#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

use bytes;
use lib 't';
require "test.pl";

my ($default, $methods, $opts) = test_parse_args();

plan tests => 4 * scalar(@$methods);

my $dict = "examples/utf8";
my ($d, @dict);
open $d, "<", $dict or die; {
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;
#$dict[$#dict] = "\x{c3}\x{a9}clair";

# Pearson and PearsonNP do pass consistently with -nul, but fail randomly without
#delete $Perfect::Hash::algo_todo{'-pearson'};
#delete $Perfect::Hash::algo_todo{'-pearsonnp'};
# CMPH works fine here
delete $Perfect::Hash::algo_todo{'-cmph-bdz_ph'};
delete $Perfect::Hash::algo_todo{'-cmph-bdz'};
delete $Perfect::Hash::algo_todo{'-cmph-bmz'};
delete $Perfect::Hash::algo_todo{'-cmph-chm'};
delete $Perfect::Hash::algo_todo{'-cmph-fch'};
delete $Perfect::Hash::algo_todo{'-cmph-chd_ph'};
delete $Perfect::Hash::algo_todo{'-cmph-chd'};
# but hanovpp still has a unicode problem
$Perfect::Hash::algo_todo{'-hanovpp'} = 1;

my $pearson8_dict = [qw(Abrus Absalom absampere Absaroka absarokite
                        \x{c3}\x{a9}clair abscess abscessed abscession
                        abscessroot abscind abscise abscision absciss)];
my $i = 0;
my $key = $dict[5];
my $suffix = "_utf8";

for my $m (@$methods) {
  my $ph = new Perfect::Hash($m eq '-pearson8' ? $pearson8_dict : $dict, $m, @$opts);
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1) for 1..3;
    $i++;
    next;
  }
  if ($m =~ /^-xxcmph/) {
    ok(1, "SKIP nyi save_c for $m");
    ok(1) for 1..3;
    $i++;
    next;
  }
  my ($nul) = grep {$_ eq '-nul'} @$opts;
  test_wmain(0, $key, $ph->perfecthash($key), $suffix, $nul);
  $i++;
  $ph->save_c("phash$suffix");
  if (ok(-f "phash$suffix.c" && -f "phash$suffix.h", "$m generated phash$suffix.c/.h")) {
    my $cmd = compile_cmd($ph, $suffix);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = $^O eq 'MSWin32' ? `phash$suffix` : `./phash$suffix`;
      $retval = $?;
      TODO: {
        local $TODO = "$m not yet" if !$m or exists $Perfect::Hash::algo_todo{$m};
        like($retstr, qr/^ok - c lookup exists/m, "$m c lookup exists");
      }
    } else {
      ok(1, "SKIP") for 1..2;
    }
    TODO: {
      local $TODO = "$m not yet" if !$m or exists $Perfect::Hash::algo_todo{$m}; # will return errcodes
      ok(!($retval>>8), "could run $m");
    }
  } else {
    ok(1, "SKIP") for 1..3;
  }
  unlink("phash$suffix","phash$suffix.c","phash$suffix.h","main$suffix.c") if $default;
}
