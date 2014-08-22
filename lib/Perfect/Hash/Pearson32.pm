package Perfect::Hash::Pearson32;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::PearsonNP;
use Perfect::Hash::XS;
our @ISA = qw(Perfect::Hash::Pearson);
use integer;
use bytes;

=head1 DESCRIPTION

Generate non-perfect pearson hash with an optimized 32bit hash function,
a pearson table of size 256 and static binary tree collision resolution.

=head1 METHODS

=head2 new $dict, @options

Computes a non-prefect, but fast pearson hash table using the given
dictionary, given as hashref or arrayref, with fast lookup.

Honored options are:

I<-false-positives>

I<-max-time seconds> stops generating a phash at seconds and uses a
non-perfect, but still fast hash then. Default: 60s.

It returns an object with @H containing the randomized
pearson lookup table of size 255.

=cut

sub new {
  goto &Perfect::Hash::PearsonNP::new;
}

=head2 hash obj, $key

=cut

#sub hash_pp {
#  my ($ph, $key ) = @_;
#  my $size = $ph->[0];
#  my $H = $ph->[1];
#  my $d = 0;
#  # process in 32bit chunks
#  for my $c (split "", $key) {
#    $d = $H->[$d ^ ord($c)];
#  }
#  return $d % $size;
#}

=head2 perfecthash $obj, $key

Look up a $key in the pearson hash table
and return the associated index into the initially 
given $dict.

Note that the hash is probably not perfect.

Without C<-false-positives> it checks if the index is correct,
otherwise it will return undef.
With C<-false-positives>, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=head2 false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>.

=cut

# local testing: pb -d lib/Perfect/Hash/PearsonPP.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearsonpp")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearson32", @ARGV)
}

1;
