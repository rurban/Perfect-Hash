package Perfect::Hash::Urban;
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::HanovPP;
use integer;
use bytes;
use Config;
our @ISA = qw(Perfect::Hash::HanovPP Perfect::Hash);
our $VERSION = '0.01';

use XSLoader;
XSLoader::load('Perfect::Hash', $VERSION);

=head1 DESCRIPTION

Improved version of HanovPP, using compressed temp. arrays
and optimized XS methods, ~2x faster than HanovPP.
Can only store index values, not strings.

WARNING: This version is still instable.

=head1 new \@dict, options

Computes a minimal perfect hash table using the given dictionary,
given as arrayref or filename.

Honored options are: I<-no-false-positives>

This version is algorithmically the same as HanovPP, but uses a faster
hash function (crc32 from libz) and ~300x smaller compressed
bitvectors for the intermediate table and the integer-only values
table, so it is limited to arrayrefs and filenames only. hashrefs with
strings as values cannot be represented for now.

It returns an object with a compressed bitvector of @G containing the
intermediate table of seeds needed to compute the index of the value
in @V.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; # arrayref or filename
  #my $max_time = grep { $_ eq '-max-time' and shift } @_;
  #$max_time = 60 unless $max_time;
  my %options = map {$_ => 1 } @_;
  #$options{'-max-time'} = $max_time;
  my ($keys, $values) = Perfect::Hash::_dict_init($dict);
  my $size = scalar @$keys;
  my $last = $size - 1;
  if (ref $dict eq 'HASH') {
    # check the types of all values, need to be integers in 0..size
    for (values %$dict) {
      die "invalid dict hashref with value $_. require values as integers in 0..$size\n"
        if $_ < 0 or $_ > $size;
    }
  }
  else {
    if (@$values) {
      my %dict = map { $keys->[$_] => $values->[$_] } 0..$last;
      $dict = \%dict;
    } else {
      my %dict = map { $keys->[$_] => $_ } 0..$last;
      $dict = \%dict;
    }
  }

  # Step 1: Place all of the keys into buckets
  my @buckets; $#buckets = $last;
  $buckets[$_] = [] for 0 .. $last; # init with empty arrayrefs
  my $buckets = \@buckets;
  my @G; $#G = $size; @G = map {0} (0..$last);
  # And for '-no-false-positives' ditto: @V as compressed index into @keys
  my @V; $#V = $last;
  #hash(0); # initialize crc

  # Step 1: Place all of the keys into buckets
  push @{$buckets[ hash($_, 0) % $size ]}, $_ for @$keys;

  # Step 2: Sort the buckets and process the ones with the most items first.
  my @sorted = sort { scalar(@{$buckets->[$b]}) <=> scalar(@{$buckets->[$a]}) } (0..$last);
  my $i = 0;
  while (@sorted) {
    my $b = $sorted[0];
    my @bucket = @{$buckets->[$b]};
    last if scalar(@bucket) <= 1; # skip the rest with 1 or 0 buckets
    shift @sorted;
    print "len[$i]=",scalar(@bucket)," [",join ",",@bucket,"]\n" if $options{-debug};
    my $d = 1;
    my $item = 0;
    my %slots;

    # Repeatedly try different values of $d (the seed) until we find a hash function
    # that places all items in the bucket into free slots.
    # Note: The resulting G indices ($d) can be MAX_LONG
    while ($item < scalar(@bucket)) {
      my $slot = hash( $bucket[$item], $d ) % $size;
      # epmh.py uses a list for slots here, we rather use a faster hash
      if (defined $V[$slot] or exists $slots{$slot}) {
        $d++; $item = 0; %slots = (); # nope, try next seed
      } else {
        $slots{$slot} = $item;
        printf "slots[$slot]=$item, d=0x%x, $bucket[$item]\n", $d if $options{-debug};
#          unless $d % 100;
        $item++;
      }
    }
    $G[hash($bucket[0], 0) % $size] = $d;
    $V[$_] = $dict->{$bucket[$slots{$_}]} for keys %slots;
    print "V=[".join(",",map{defined $_ ? $_ : ""} @V),"]\n" if $options{-debug};
    print "buckets[$i]:",scalar(@bucket)," d=$d @bucket\n" if $options{-debug};
#      unless $b % 1000;
    $i++;
  }

  # Only buckets with 1 item remain. Process them more quickly by directly
  # placing them into a free slot. Use a negative value of $d to indicate
  # this.
  my @freelist;
  for my $i (0..$last) {
    push @freelist, $i unless defined $V[$i];
  }
  print "len[freelist]=",scalar(@freelist)," [",join ",",@freelist,"]\n"  if $options{-debug};

  print "xrange(",$last - $#sorted - 1,", $size)\n" if $options{-debug};
  while (@sorted) {
    $i = $sorted[0];
    my @bucket = @{$buckets->[$i]};
    last unless scalar(@bucket);
    shift @sorted;
    my $slot = pop @freelist;
    # We subtract one to ensure it's negative even if the zeroeth slot was
    # used.
    $G[hash($bucket[0], 0) % $size] = - $slot-1;
    $V[$slot] = $dict->{$bucket[0]};
  }

  print "G=[".join(",",@G),"],\nV=[".join(",",@V),"]\n" if $options{-debug};
  # Last step: compress G and V into bitvectors accessed via vec().
  # Needed bits per index: length sprintf "%b",$size
  # Since perl cannot access multi-byte bits via vec, it needs to be a power
  # of two from 1 to 32, with a portable warning for 64.
  # Devel::Size, with n=20: 88 vs 1664+1656 byte
  # We use our own fast vec function. http://blogs.perl.org/users/rurban/2014/08/vec-is-slow-little-endian-and-limited.html
  # find min and max G entries:
  my ($min, $max) = (0, 0);
  for (@G) {
    $min = $_ if $_ < $min;
    $max = $_ if $_ > $max;
  }
  my $maxindex = abs($min) > $max ? abs($min) : $max;
  my $bits = 1+length(sprintf "%b",$maxindex); # +1 for negative values
  for (2,4,8,16,32,($Config{ptrsize}==8?(64):())) {
    next if $bits > $_;
    $bits = $_; last;
  }
  my $G = "\0" x int($bits * $size / 4);
  for my $i (0..$#G) {
    nvecset($G, $i, $bits, $G[$i]) if $G[$i];
  }
  for my $i (0..$#V) {
    nvecset($G, $i+$size, $bits, $V[$i]) if $V[$i];
  }
  printf("\$G\[$bits]=\"%s\":%d\n", unpack("h*", $G), length($G))
    if $options{-debug};

  if (exists $options{'-no-false-positives'}) {
    if (exists $options{'-debug'}) {
      return bless [$G, $bits, \%options, $keys, \@G, \@V], $class;
    } else {
      return bless [$G, $bits, \%options, $keys], $class;
    }
  } else {
    return bless [$G, $bits, \%options], $class;
  }
}

=head1 perfecthash $obj, $key

Look up a $key in the minimal perfect hash table
and return the associated index into the initially 
given $dict.

With -no-false-positives it checks if the index is correct,
otherwise it will return undef.
Without -no-false-positives, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my $v = $ph->iv_perfecthash($key);
  return $v == -1 ? undef : $v;
}

# use the new XS version now
sub pp_perfecthash {
  my ($ph, $key ) = @_;
  my ($G, $bits) = ($ph->[0], $ph->[1]);
  my $size = 4 * length($G) / $bits;
  my $voff = $size;
  my $h = hash($key, 0) % $size;
  my $d = nvecget($G, $h, $bits);
  # fix negative sign of d
  $d = ($d - (1<<$bits)) if $d >= 1<<($bits-1);
  my $v = $d < 0
    ? nvecget($G, $voff + (- $d-1), $bits)
    : $d == 0 ? nvecget($G, $voff + $h, $bits)
              : nvecget($G, $voff + hash($key, $d) % $size, $bits);
  if ($ph->[2]->{'-debug'}) {
    printf("ph: h0=%2d d=%3d v=%2d\t",$h,$d>0?hash($key,$d)%$size:$d,$v);
  }
  # -no-false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the exists $ph->[2]->{-no-false-positives} check for now
  if ($ph->[3]) {
    return ($ph->[3]->[$v] eq $key) ? $v : undef;
  } else {
    return $v;
  }
}

=head1 false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is 1, unless you created the hash with the
option C<-no-false-positives>.

=cut

# use the HanovPP version now
sub false_positives {
  return !exists $_[0]->[2]->{'-no-false-positives'};
}

=head1 hash string, [salt]

Try to use a hw-assisted crc32 from libz (aka zlib).

Because Compress::Raw::Zlib::crc32 does not use zlib, it only uses the
slow SW fallback version.  We really need a interface library to
zlib. A good name might be Compress::Zlib, oh my.

=cut

#see the XS implementation in Hash.xs

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=cut

sub c_hash_impl {
  my ($ph, $base) = @_;
  if ($ph->option('-nul')) {
    return "
#include \"zlib.h\"

/* libz crc32 */
inline
unsigned $base\_hash_len (unsigned d, const char *s, const int len) {
    return crc32(d, s, len);
}
"
  } else {
    return "
#include <string.h>
#include \"zlib.h\"

/* libz crc32 */
inline
unsigned $base\_hash (unsigned d, const char *s) {
    return crc32(d, s, strlen(s));
}
";
  }
}

sub save_xs { die "NYI" }

sub _test_tables {
  my $ph = Perfect::Hash::Urban->new("examples/words1000",qw(-debug -no-false-positives));
  my $keys = $ph->[3];
  my $size = scalar @$keys;
  my $G = $ph->[4];
  my $V = $ph->[5];
  for (0..$size-1) {
    my $k = $keys->[$_];
    my $d = $G->[$_] < 0 ? 0 : $G->[$_];
    printf "%2d: ph=%2d pph=%2s  G[%2d]=%3d  V[%2d]=%3d  h(%2d,%d)=%2d %s\n",
      $_,$ph->perfecthash($k),$ph->pp_perfecthash($k),
      $_,$G->[$_],$_,$V->[$_],
      $_,$d,hash($k,$d)%$size,
      $k;
  }
}

# local testing: pb -d lib/Perfect/Hash/Urban.pm examples/words20 -debug
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-urban")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-urban", @ARGV)
}

1;
