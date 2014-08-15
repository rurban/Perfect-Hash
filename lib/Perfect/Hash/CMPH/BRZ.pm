package Perfect::Hash::CMPH::BRZ;

use strict;
our $VERSION = '0.01';
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash Perfect::Hash::C);

=head1 DESCRIPTION

XS interface to the cmph-2.0 BRZ algorithm.
See L<http://cmph.sourceforge.net/brz.html>

BRZ is an external memory based algorithm esp. suited to huge
dictionaries, which can easily scale to billions of entries.

The algorithm is linear on the size of keys to construct a MPHF, which
is optimal. For instance, for a collection of 1 billion URLs collected
from the web, each one 64 characters long on average, the time to
construct a MPHF using a 2.4 gigahertz PC with 500 megabytes of
available main memory is approximately 3 hours. Second, the algorithm
needs a small a priori defined vector of one byte entries in main
memory to construct a MPHF. For the collection of 1 billion URLs and
using , the algorithm needs only 5.45 megabytes of internal
memory. Third, the evaluation of the MPHF for each retrieval requires
three memory accesses and the computation of three universal hash
functions. This is not optimal as any MPHF requires at least one
memory access and the computation of two universal hash
functions. Fourth, the description of a MPHF takes a constant number
of bits for each key, which is optimal. For the collection of 1
billion URLs, it needs 8.1 bits for each key, while the theoretical
lower bound is bits per key.

=head1 METHODS

See L<Perfect::Hash::CMPH>

=cut

# local testing: p -d -Mblib lib/Perfect/Hash/CMPH/BRZ.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
