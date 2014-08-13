package Perfect::Hash::CMPH::BMZ8;

use strict;
our $VERSION = '0.01';
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash);

=head1 DESCRIPTION

XS interface to the cmph-2.0 BMZ8 algorithm.
See http://cmph.sourceforge.net/bmz.html

=head1 METHODS

See L<Perfect::Hash::CMPH>

=cut

# local testing: p -d -Mblib lib/Perfect/Hash/CMPH/BMZ8.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
