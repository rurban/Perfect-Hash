package Perfect::Hash::CMPH::BDZ;

use strict;
our $VERSION = '0.01';
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash);

=head1 DESCRIPTION

XS interface to the cmph-2.0 BDZ algorithm.
See http://cmph.sourceforge.net/chd.html

=head1 METHDOS

=over

=item new $filename, @options

Computes a minimal perfect hash table using the given dictionary,
given as hashref or arrayref or filename.

Honored options are: I<none yet>

Planned: I<-minimal>

=cut

sub new {
  return Perfect::Hash::CMPH::_new(@_);
}

=item perfecthash $ph, $key

Look up a $key in the minimal perfect hash table and return the
associated index into the initially given $dict.

Checks if the index is correct, otherwise it will return undef.

=item false_positives

Returns undef, as cmph hashes always store the keys.

=item save_c fileprefix, options

See L<Perfect::Hash::CMPH/save_c>

=back

=cut

# local testing: p -d -Ilib lib/Perfect/Hash/CMPH/BDZ.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
