#!/usr/bin/perl

# Test that our META.yml file matches the current specification.

use strict;
BEGIN {
  $|  = 1;
  $^W = 1;
}

my $MODULE = 'Test::CPAN::Meta 0.12';

# Don't run tests for installs
use Test::More;
plan skip_all => 'This test is only run for the module author'
    unless -d '.git' || $ENV{IS_MAINTAINER};

# Load the testing module
eval "use $MODULE;";
if ( $@ ) {
  plan( skip_all => "$MODULE not available for testing" );
  die "Failed to load required release-testing module $MODULE 0.12"
    if -d '.git' || $ENV{IS_MAINTAINER};
}
meta_yaml_ok();
