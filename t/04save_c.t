#!/usr/bin/perl -w
use Test::More;
use Perfect::Hash;

#use Config;
use lib 't';
require "test.pl";

my ($default, $methods, $opts) = opt_parse_args();

plan tests => 5 * scalar(@$methods);

my ($dict, $dictarr, $size, $custom_size) = opt_dict_size($opts, "examples/words500");
my $small_dict = $size > 255 ? "examples/words20" : $dict;

# CHM passes pure-perl, but not compiled yet
$Perfect::Hash::algo_todo{'-cmph-chm'} = 1;

my $i = 0;
for my $m (@$methods) {
  my $used_dict = $m eq '-pearson8'
    ? $small_dict
    : $m eq '-gperf'
      ? $dictarr
      : $dict;
  my $ph = new Perfect::Hash($used_dict, $m, @$opts);
  unless ($ph) {
    ok(1, "SKIP empty phash $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  if ($m =~ /^-cmph/) {
    ok(1, "SKIP nyi save_c for $m");
    ok(1) for 1..4;
    $i++;
    next;
  }
  my ($nul) = grep {$_ eq '-nul'} @$opts;
  test_wmain($m, 1, 'AOL', $ph->perfecthash('AOL'), $nul);
  $i++;
  $ph->save_c("phash");
  if (ok(-f "phash.c" && -f "phash.h", "$m generated phash.c/.h")) {
    my $cmd = compile_static($ph);
    diag($cmd) if $ENV{TEST_VERBOSE};
    my $retval = system($cmd);
    if (ok(!($retval>>8), "could compile $m")) {
      my $retstr = $^O eq 'MSWin32' ? `phash` : `./phash`;
      $retval = $?;
      TODO: {
        local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m} and $m !~ /^-cmph/;
        like($retstr, qr/^ok - c lookup exists/m, "$m c lookup exists");
      }
      TODO: {
        local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m};
        like($retstr, qr/^ok - c lookup notexists/m, "$m c lookup notexists");
      }
    } else {
      ok(1, "SKIP") for 0..1;
    }
    TODO: {
      local $TODO = "$m" if exists $Perfect::Hash::algo_todo{$m}; # will return errcodes
      ok(!($retval>>8), "could run $m");
    }
  } else {
    ok(1, "SKIP") for 0..3;
  }
  unlink("phash","phash.c","phash.h","main.c") if $default;
}
