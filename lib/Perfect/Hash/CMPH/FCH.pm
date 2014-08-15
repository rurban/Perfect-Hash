package Perfect::Hash::CMPH::FCH;

use strict;
our $VERSION = '0.01';
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash Perfect::Hash::C);

=head1 DESCRIPTION

XS interface to the cmph-2.0 FCH algorithm.
See http://cmph.sourceforge.net/fch.html

The total memory consumption of FCH algorithm for generating a minimal
perfect hash function (MPHF) is: O(n) + 9n + 8cn/(log(n) + 1)
bytes. The value of parameter c must be greater than or equal to 2.6.

Memory consumption to store the resulting function: We only need to
store the g function and a constant number of bytes for the seed of
the hash functions used in the resulting MPHF. Thus, we need
cn/(log(n) + 1) + O(1) bytes.

E.A. Fox, Q.F. Chen, and L.S. Heath. A faster algorithm for
constructing minimal perfect hash functions. In Proc. 15th Annual
International ACM SIGIR Conference on Research and Development in
Information Retrieval, pages 266-273, 1992.
L<http://cmph.sourceforge.net/papers/fch92.pdf>

=head1 METHODS

See L<Perfect::Hash::CMPH>

=cut

# local testing: p -d -Mblib lib/Perfect/Hash/CMPH/FCH.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
