package Perfect::Hash::Hanov;
#use coretypes;
BEGIN {$int::x = $num::x = $str::x} # for B::CC type optimizations
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::HanovPP;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash::HanovPP Perfect::Hash::C);
our $VERSION = '0.01';

use XSLoader;
XSLoader::load('Perfect::Hash', $VERSION);

=head1 DESCRIPTION

HanovPP with crc32

This version is stable and relatively fast even for bigger dictionaries.

=head1 METHODS

=over

=item new $dict, @options

Computes a minimal perfect hash table using the given dictionary,
given as hashref, arrayref or filename.

Honored options are: 

I<-false-positives>
I<-nul>

It returns an object with a list of [\@G, \@V, ...].
@G contains the intermediate table of seeds needed to compute the
index of the value in @V.  @V contains the values of the dictionary.

=item perfecthash $ph, $key

Look up a $key in the minimal perfect hash table
and return the associated index into the initially 
given $dict.

Without C<-false-positives> it checks if the index is correct,
otherwise it will return undef.
With C<-false-positives>, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=item false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>, which decreases the required space from
B<3n> to B<2n>.

=item hash string, [salt]

Use the hw-assisted crc32 from libz (aka zlib).

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=item hashname $ph

Returns "crc32_zlib", "crc32_sse42" or "fnv",
depending on the build-time generated HAVE_ZLIB and __SSE4_2__ CFLAGS.

=item c_hash_impl $ph, $base

String for C code for the hash function, depending on hashname and C<-nul>.

=cut

sub c_hash_impl {
  my ($ph, $base) = @_;
  my $hashname = $ph->hashname();
  my $s;
  if ($hashname eq 'crc32_zlib') {
    $s = "
#include \"zlib.h\" /* libz crc32 */";
  }
  elsif ($hashname eq 'crc32_sse42') {
    # TODO windows stdint
    $s = <<'EOF';
#ifdef __SSE4_2__
#include <stdint.h>
#include <smmintrin.h>

/* Byte-boundary alignment issues */
#define ALIGN_SIZE      0x08UL
#define ALIGN_MASK      (ALIGN_SIZE - 1)
#define CALC_CRC(op, crc, type, buf, len)                               \
  do {                                                                  \
    for (; (len) >= sizeof (type); (len) -= sizeof(type), buf += sizeof (type)) { \
      (crc) = op((crc), *(type *) (buf));                               \
    }                                                                   \
  } while(0)


/* iSCSI CRC-32C using the Intel hardware instruction. */
/* for better parallelization with bigger buffers see
   http://www.drdobbs.com/parallel/fast-parallelized-crc-computation-using/229401411 */
unsigned int crc32(unsigned int crc, const char *buf, int len)
{
    /* XOR the initial CRC with INT_MAX */
    crc ^= 0xFFFFFFFF;

    /* Align the input to the word boundary */
    for (; (len > 0) && ((size_t)buf & ALIGN_MASK); len--, buf++) {
        crc = _mm_crc32_u8(crc, *buf);
    }

#ifdef __x86_64__ /* or Aarch64... */
    CALC_CRC(_mm_crc32_u64, crc, uint64_t, buf, len);
#endif
    CALC_CRC(_mm_crc32_u32, crc, uint32_t, buf, len);
    CALC_CRC(_mm_crc32_u16, crc, uint16_t, buf, len);
    CALC_CRC(_mm_crc32_u8, crc, uint8_t, buf, len);

    return (crc ^ 0xFFFFFFFF);
}
#endif
EOF

  }
  else {
    return Perfect::Hash::HanovPP::c_hash_impl(@_);
  }

  if ($ph->option('-nul')) {
    $s .= "
#define $base\_hash_len(d, s, len) crc32((d), (const unsigned char*)(s), (len))
";
  } else {
    $s .= "
#define $base\_hash(d, s) crc32((d), ((const unsigned char*)s), strlen(s))
";
  }
  return $s;
}

=item c_lib c_include

Compiler flags depending on the hashname.
Hanov and Urban need -lz or -msse42 for our own sse4.2 iSCSI CRC32 hash function.

TODO: honor given LIBS paths to Makefile.PL

=back

=cut

sub c_lib {
  # TODO zlib uses the HW iSCSI CRC32 hash function, but it does *not* on macports.
  return ($_[0]->hashname() eq 'crc32_zlib') ? " -lz" : "";
}
sub c_include { 
  return ($_[0]->hashname() eq 'crc32_sse42') ? " -msse4.2" : "";
}

sub _test_tables {
  my $ph = __PACKAGE__->new("examples/words20",qw(-debug));
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

# local testing: p -d -Ilib lib/Perfect/Hash/Hanov.pm examples/words20
unless (caller) {
  &Perfect::Hash::_test('-hanov',@ARGV)
}

1;
