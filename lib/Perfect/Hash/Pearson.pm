package Perfect::Hash::Pearson;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use integer;
use bytes;

use Exporter 'import';
our @ISA = qw(Perfect::Hash Exporter);
our @EXPORT = qw(hash shuffle cost collisions);

=head1 DESCRIPTION

A Pearson hash is generally not perfect, but generates one of the
fastest lookups.  This version generates arbitrary sized pearson
lookup tables and thus should be able to find a perfect hash, but
success is very unlikely. The generated lookup might be however still
faster than most other hash tables for <100.000 keys.

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

=head1 new $dict, @options

Computes a brute-force n-bit Pearson hash table using the given
dictionary, given as hashref or arrayref, with fast lookup.

Honored options are:

I<-no-false-positives>

I<-max-time seconds> stops generating a phash at seconds and uses a
non-perfect, but still fast hash then. Default: 60s.

It returns an object with @H containing the randomized
pearson lookup table.

=cut

sub new {
  my $class = shift or die;
  # return Perfect::Hash::PearsonNP::new($class, @_);
  my $dict = shift; #hashref or arrayref or filename
  my $max_time = grep { $_ eq '-max-time' and shift } @_;
  $max_time = 60 unless $max_time;
  my %options = map {$_ => 1 } @_;
  $options{'-max-time'} = $max_time;
  my ($keys, $values) = _dict_init($dict);
  my $size = scalar @$keys;
  my $last = $size-1;

  # Step 1: Generate @H
  # round up to 2 complements, with ending 1111's
  my $i = 1;
  while (2**$i++ < $size) {}
  my $hsize = 2**($i-1) - 1;
  print "size=$size hsize=$hsize\n";
  # TODO: bitvector string with vec
  my @H; $#H = $hsize;
  $i = 0;
  $H[$_] = $i++ for 0 .. $hsize; # init with ordered sequence
  my $H = \@H;

  # Step 2: shuffle @H until we get a good maxbucket, only 0 or 1
  # https://stackoverflow.com/questions/1396697/determining-perfect-hash-lookup-table-for-pearson-hash
  # expected max: birthday paradoxon
  my ($C, @best, $sum, $maxsum, $max, $counter, $maxcount);
  $maxcount = $last; # when to stop the search. should be $last !
  # we should rather set a time-limit like 1 min.
  my $t0 = [gettimeofday];
  do {
    # this is not good. we should non-randomly iterate over all permutations
    shuffle($H);
    ($sum, $max) = cost($H, $keys);
    $counter++;
    print "$counter sum=$sum, max=$max\n" if $options{-debug};
    if (!defined($maxsum) or $sum < $maxsum or $max == 1) {
      $maxsum = $sum;
      @best = @$H;
    }
  } while ($max > 1 and $counter < $maxcount and tv_interval($t0) < $max_time);

  if ($max > 1) {
    @H = @best;
    $H = \@H;
    ($sum, $max) = cost($H, $keys);
    # Step 3: Store collisions as no perfect hash was found
    print "list of collisions: sum=$sum, maxdepth=$max\n";
    $C = collisions($H, $keys, $values);
  }

  if (exists $options{'-no-false-positives'}) {
    return bless [$size, $H, $C, \%options, $keys], $class;
  } else {
    return bless [$size, $H, $C, \%options], $class;
  }
}

sub shuffle {
  # the "Knuth Shuffle", a random shuffle to create good permutations
  my $H = $_[0];
  my $last = scalar(@$H);
  for my $i (0 .. $last) {
    my $tmp = $_[0]->[$i];
    my $j = $i + int rand($last-$i);
    $_[0]->[$i]= $_[0]->[$j];
    $_[0]->[$j] = $tmp;
  }
  delete $H->[$last];
}

sub cost {
  my ($H, $keys) = @_;
  my @N = (); $#N = scalar(@$H) - 1;
  $N[$_] = 0 for 0..$#N;
  my ($sum, $max) = (0, 0);
  my $size = scalar @$keys;
  for (@$keys) {
    my $h = hash($H, $_, $size);
    $N[$h]++;
    $sum++ if $N[$h] > 1;
    $max = $N[$h] if $max < $N[$h];
  }
  return ($sum, $max);
}

sub collisions {
  my ($H, $keys, $values) = @_;
  my $size = scalar(@$keys);
  my @C = (); $#C = $size - 1;
  $C[$_] = [] for 0..$#C;
  unless (@$values) { $values = [0 .. $size-1]; }
  my $i = 0;
  for (@$keys) {
    my $h = hash($H, $_, $size); # e.g. a=>1 b=>11 c=>111
    push @{$C[$h]}, [$_, $values->[$i]];
    $i++;
  }
  @C = map { scalar @$_ > 1 ? $_ : undef } @C;
  return \@C;
}

=head1 hash \@H, salt, string

=cut

sub hash {
  my ($H, $key, $size ) = @_;
  my $d = length $key || 0;
  my $hsize = scalar @$H;
  for (split //, $key) { # under use bytes
    $d = $H->[($d ^ ord($_)) % $hsize];
  }
  return $d % $size;
}

=head1 perfecthash $obj, $key

Look up a $key in the pearson hash table
and return the associated index into the initially 
given $dict.

Note that the hash is probably not perfect.

With -no-false-positives it checks if the index is correct,
otherwise it will return undef.
Without -no-false-positives, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my $H = $ph->[1];
  my $C = $ph->[2];
  my $v = hash($H, $key, $ph->[0]);
  if ($C and $C->[$v] and @{$C->[$v]} > 1) {
    print "check ".scalar @{$C->[$v]}." collisions for $key\n" if $ph->[3]->{-debug};
    for (@{$C->[$v]}) {
      if ($key eq $_->[0]) {
        $v = $_->[1];
        last;
      }
    }
  }
  # -no-false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the exists $ph->[2]->{-no-false-positives} check for now
  if ($ph->[4]) {
    return ($ph->[4]->[$v] eq $key) ? $v : undef;
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
  return !exists $_[0]->[3]->{'-no-false-positives'};
}

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=back

=cut

# local testing: pb -d lib/Perfect/Hash/Pearson.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearson")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearson", @ARGV)
}

1;
