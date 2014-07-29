package Perfect::Hash::Urban;
use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash);
our $VERSION = '0.01';

use XSLoader;
XSLoader::load('Perfect::Hash');

=head1 DESCRIPTION

Improved version HanovPP, using compressed temp. arrays.

=head1 new $dict, options

Computes a minimal perfect hash table using the given dictionary,
given as hashref, arrayref or filename.

Honored options are: I<-no-false-positives>

This version needs O(3n) space so far, but this is gotta get better soon.

It returns an object with a compressed bitvector of @G containing the
intermediate table of seeds needed to compute the index of the value
in @V.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my %options = map {$_ => 1 } @_;
  my ($keys, $values) = Perfect::Hash::_dict_init($dict);
  my $size = scalar @$keys;
  my $last = $size - 1;
  if (ref $dict ne 'HASH') {
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
  # TODO: rather use a bitvector for G. And for '-no-false-positives' ditto:
  # @V as compressed index into @keys
  my @G; $#G = $size; @G = map {0} (0..$last);
  my @V; $#V = $last;
  hash(0); # initialize crc

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
    print "len[$i]=",scalar(@bucket),"\n" if $options{-debug};
    my int $d = 1;
    my int $item = 0;
    my %slots;

    # Repeatedly try different values of $d (the seed) until we find a hash function
    # that places all items in the bucket into free slots.
    while ($item < scalar(@bucket)) {
      my $slot = hash( $bucket[$item], $d ) % $size;
      # epmh.py uses a list for slots here, we rather use a faster hash
      if (defined $V[$slot] or exists $slots{$slot}) {
        $d++; $item = 0; %slots = (); # nope, try next seed
      } else {
        $slots{$slot} = $item;
        printf "slots[$slot]=$item, d=0x%x, $bucket[$item] from @bucket\n", $d if $options{-debug};
#          unless $d % 100;
        $item++;
      }
    }
    $G[hash($bucket[0], $d) % $size] = $d;
    $V[$_] = $dict->{$bucket[$slots{$_}]} for keys %slots;
    print "[".join(",",@V),"]\n" if $options{-debug};
    print "buckets[$i]:",scalar(@bucket)," d=$d\n" if $options{-debug};
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
  print "len[freelist]=",scalar(@freelist),"\n" if $options{-debug};

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
  print "[".join(",",@G),"],\n[".join(",",@V),"]\n" if $options{-debug};
  # Last step: compress G and V into bitvectors with vect
  # ...

  if (exists $options{'-no-false-positives'}) {
    return bless [\@G, \@V, \%options, $keys], $class;
  } else {
    return bless [\@G, \@V, \%options], $class;
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
  my ($G, $V) = ($ph->[0], $ph->[1]);
  my $size = scalar(@$G);
  my $d = $G->[hash($key) % $size];
  my $v = $d < 0 ? $V->[- $d-1] : $V->[hash($key, $d) % $size];
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

sub false_positives {
  return !exists $_[0]->[2]->{'-no-false-positives'};
}

=head1 hash string, [salt]

Try to use a hw-assisted crc32 from libz (aka zlib).

Because Compress::Raw::Zlib::crc32 doesn't use libz, it only uses the
slow SW fallback version.  We really need a interface library to
zlib. A good name might be Compress::Zlib, oh my.

=cut

# local testing: pb -d lib/Perfect/Hash/Urban.pm examples/words20 -debug
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-urban")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-urban", @ARGV)
}

1;
