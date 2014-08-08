package Perfect::Hash::Hanov;
#use coretypes;
BEGIN {$int::x = $num::x = $str::x}
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::HanovPP;
use Perfect::Hash::Urban;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash::HanovPP Perfect::Hash::C);
our $VERSION = '0.01';

=head1 DESCRIPTION

HanovPP with crc32

This version is stable and relatively fast even for bigger dictionaries.

=head1 METHODS

=over

=item new $dict, @options

Computes a minimal perfect hash table using the given dictionary,
given as hashref, arrayref or filename.

Honored options are: I<-no-false-positives>

It returns an object with a list of [\@G, \@V, ...].
@G contains the intermediate table of seeds needed to compute the
index of the value in @V.  @V contains the values of the dictionary.

=item perfecthash $obj, $key

Look up a $key in the minimal perfect hash table
and return the associated index into the initially 
given $dict.

With -no-false-positives it checks if the index is correct,
otherwise it will return undef.
Without -no-false-positives, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=item false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is 1, unless you created the hash with the option
C<-no-false-positives>, which increases the required space from
2n to B<3n>.

=item hash string, [salt]

Use the hw-assisted crc32 from libz (aka zlib).

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=item c_hash_impl $ph, $base

String for C code for the hash function, depending on C<-nul>.

=cut

sub c_hash_impl {
  my ($ph, $base) = @_;
  if ($ph->option('-nul')) {
    return "
#include \"zlib.h\"
/* libz crc32 */
#define $base\_hash_len(d, s, len) crc32((d), (s), (len))
"
  } else {
    return "
#include <string.h>
#include \"zlib.h\"
/* libz crc32 */
#define $base\_hash(d, s) crc32((d), (s), strlen(s))
";
  }
}

=item c_lib

Hanov and Urban need -lz.

TODO: honor given LIBS paths to Makefile.PL

=back

=cut

sub c_lib { " -lz" }

sub _test_tables {
  my $ph = __PACKAGE__->new("examples/words20",qw(-debug -no-false-positives));
  my $keys = $ph->[3];
  # bless [\@G, \@V, \%options, $keys], $class;
  my $G = $ph->[0];
  my $V = $ph->[1];
  for (0..19) {
    my $k = $keys->[$_];
    my $d = $G->[$_] < 0 ? 0 : $G->[$_];
    printf "%2d: ph=%2d   G[%2d]=%3d  V[%2d]=%3d   h(%2d,%d)=%2d %s\n",
      $_,$ph->perfecthash($k),
      $_,$G->[$_],$_,$V->[$_],
      $_,$d,hash($k,$d)%20,
      $k;
  }
}

# local testing: p -d -Ilib lib/Perfect/Hash/HanovPP.pm examples/words20
unless (caller) {
  &Perfect::Hash::_test(@ARGV)
}

1;
