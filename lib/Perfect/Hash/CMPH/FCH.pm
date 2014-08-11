package Perfect::Hash::CMPH::FCH;

our $VERSION = '0.01';
use strict;
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash);

=head1 DESCRIPTION

XS interface to the cmph-2.0 FCH algorithm.
See http://cmph.sourceforge.net/fch.html

=head1 METHDOS

=head2 new $filename, @options

Computes a minimal perfect hash table using the given dictionary,
given as hashref or arrayref or filename.

Honored options are: I<none yet>

Planned: I<-minimal>

=head2 perfecthash $ph, $key

Look up a $key in the minimal perfect hash table and return the
associated index into the initially given $dict.

Checks if the index is correct, otherwise it will return undef.

=head2 false_positives

Returns undef, as cmph hashes always store the keys.

=head2 save_c NYI

=cut

# local testing: p -d -Ilib lib/Perfect/Hash/CMPH/CHD.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
