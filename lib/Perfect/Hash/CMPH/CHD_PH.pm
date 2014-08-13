package Perfect::Hash::CMPH::CHD_PH;

use strict;
our $VERSION = '0.01';
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash Perfect::Hash::C);

=head1 DESCRIPTION

XS interface to the cmph-2.0 CHD_PH algorithm.
See http://cmph.sourceforge.net/chd.html

=head1 METHODS

See L<Perfect::Hash::CMPH>

=cut

# local testing: p -d -Ilib lib/Perfect/Hash/CMPH/CHD.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
