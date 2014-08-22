package Perfect::Hash::MoreHashes;
use Perfect::Hash::C;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);
our $VERSION = '0.01';

=head1 NAME

Perfect::Hash::MoreHashes - perl and c implemenations of alternative hash funcs

=head1 METHODS

=over

=item hash_murmur3 string, [seed]

pure-perl murmur3 int32 finalizer

=cut

sub hash_murmur3 {
  use bytes;
  my $ph = shift;
  my str $str = shift;
  my int $h = shift || 0;
  for my $c (split "", $str) {
    $h = $h ^ ord($c); # XXX better slice strings into 4 bytes
    $h ^= $h >> 16;
    $h *= 0x85ebca6b;
    $h ^= $h >> 13;
    $h *= 0xc2b2ae35;
    $h ^= $h >> 16;
  }
  return $h
}

=item c_hash_impl_fnv1_mantis string, [seed]

C version of a faster FNV1 variant, incompat to our pure-perl fnv1

=cut

sub c_hash_impl_fnv1_mantis {
  my ($ph, $base) = @_;
  return "
#ifdef _MSC_VER
#define INLINE __inline
#else
#define INLINE inline
#endif

#ifdef _MSC_VER
# define rotl(a,b) _rotl(a,b)
#else
static inline rotl(unsigned int x, unsigned char r) {
  asm(\"roll %1,%0\" : \"+r\" (x) : \"c\" (r));
  return x;
}
#endif

/* optimized Mantis FNV from http://www.sanmayce.com/Fastest_Hash/
   but without 64 bit and xmm 128 bit extensions.
*/
static INLINE
unsigned $base\_hash_mantis(unsigned d, const unsigned char *str, const int len) {
  const unsigned int PRIME = 709607;        /* ad3e7 */
  unsigned int hash32 = d ? d : 2166136261; /* 811c9dc5 */
  const char *p = str;

  /* Cases: 0,1,2,3,4,5,6,7,...,15 */
  if (len & 2*sizeof(int)) {
    hash32 = (hash32 ^ *(unsigned int*)p) * PRIME;
    p = sizeof(int);
    hash32 = (hash32 ^ *(unsigned int*)p) * PRIME;
    p += sizeof(int);
  }
  /* Cases: 0,1,2,3,4,5,6,7 */
  if (len & sizeof(int)) {
    hash32 = (hash32 ^ *(unsigned short*)p) * PRIME;
    p = sizeof(int);
  }
  if (len & sizeof(short)) {
    hash32 = (hash32 ^ *(unsigned short*)p) * PRIME;
    p += sizeof(short);
  }
  if (len & 1)
    hash32 = (hash32 ^ *p) * PRIME;
    p += 1;
  }
  len -= p-str;

  for(; len > 2*sizeof(int); len -= 2*sizeof(int), p += 2*sizeof(int)) {
	hash32 = (hash32 ^ (rotl(*(int *)p,5) ^ *(int *)(p+4))) * PRIME;
  }
  hash32 = (hash32 ^ *(short*)(p+0*sizeof(short))) * PRIME;
  hash32 = (hash32 ^ *(short*)(p+1*sizeof(short))) * PRIME;
  hash32 = (hash32 ^ *(short*)(p+2*sizeof(short))) * PRIME;
  hash32 = (hash32 ^ *(short*)(p+3*sizeof(short))) * PRIME;
  return hash32 ^ (hash32 >> 16);
}

";
}

=back

=cut

1;
