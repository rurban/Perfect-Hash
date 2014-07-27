package Perfect::Hash::PearsonNP;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use integer;
our @ISA = qw(Perfect::Hash);

=head1 DESCRIPTION

Generate non-perfect pearson hash with static binary tree
collision resolution.

Good for 5-100.000 keys.

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

=head1 new $dict, options

Computes a non-prefect, but fast pearson hash table using the given
dictionary, given as hashref or arrayref, with fast lookup.

Honored options are: I<-no-false-positives>

It returns an object with @H containing the randomized
pearson lookup table of size 255.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref or arrayref, file later
  my %options = map {$_ => 1 } @_;
  my $size;
  my $dictarray;
  if (ref $dict eq 'ARRAY') {
    my $i = 0;
    my %dict = map {$_ => $i++} @$dict;
    $size = scalar @$dict;
    $dictarray = $dict;
    $dict = \%dict;
  } else {
    die "new $class: wrong dict argument. arrayref or hashref expected"
      if ref $dict ne 'HASH';
    $size = scalar(keys %$dict) or
      die "new $class: empty dict argument";
    if (exists $options{'-no-false-positives'}) {
      my @arr = ();
      $#arr = $size;
      for (sort keys %$dict) {
        $arr[$_] = $dict->{$_};
      }
      $dictarray = \@arr;
    }
  }
  my $last = $size-1;

  # Step 1: Generate @H
  # TODO: bitvector string with vec
  my @H; $#H = 255;
  my $i = 0;
  $H[$_] = $i++ for 0 .. 255; # init with ordered sequence
  my $H = \@H;
  my @best;
  my $maxbuckets = 0; # birthday paradoxon
  my ($buckets, $max, $counter);
  my $maxcount = 30; # when to stop the search. exhaustive is 255!
  # Step 2: shuffle @H until we get a good max, only 0 or 1
  # This is the problem: https://stackoverflow.com/questions/1396697/determining-perfect-hash-lookup-table-for-pearson-hash
  do {
    # this is not good. we should non-randomly iterate over all permutations
    shuffle($H);
    ($buckets, $max) = cost($H, $dict);
    $counter++;
    #print "$counter sum=$buckets, max=$max\n";
    if ($buckets > $maxbuckets or $max == 1) {
      $buckets = $maxbuckets;
      @best = @$H;
    }
  } while ($max > 1 and $counter < $maxcount); # $n!
  @H = @best;
  $H = \@H;
  # TODO Step 3: Store binary collision trees

  if (exists $options{'-no-false-positives'}) {
    return bless [$H, \%options, $dictarray], $class;
  } else {
    return bless [$H, \%options], $class;
  }
}

sub shuffle {
  # the "Knuth Shuffle", a random shuffle to create good permutations
  my $H = $_[0];
  my $last = scalar(@$H) - 1;
  for my $i (0 .. $last) {
    my $tmp = $_[0]->[$i];
    my $j = $i + int rand($last-$i);
    $_[0]->[$i]= $_[0]->[$j];
    $_[0]->[$j] = $tmp;
  }
}

sub cost {
  my ($H, $dict) = @_;
  my @N = (); $#N = 255;
  $N[$_] = 0 for 0..255;
  my ($buckets, $maxbuckets) = (0, 0);
  for (values %$dict) {
    my $h = hash($H, $_);
    $N[$h]++;
    $buckets++ if $N[$h] > 1;
    $maxbuckets = $N[$h] if $maxbuckets < $N[$h];
  }
  return ($buckets, $maxbuckets);
}

=head1 perfecthash $obj, $key

Look up a $key in the pearson hash table
and return the associated index into the initially 
given $dict.

With -no-false-positives it checks if the index is correct,
otherwise it will return undef.
Without -no-false-positives, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my $H = $ph->[0];
  my $v = hash($H, $key);
  # -no-false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the exists $ph->[2]->{-no-false-positives} check for now
  if ($ph->[2]) {
    return ($ph->[2]->[$v] eq $key) ? $v : undef;
  } else {
    return $v;
  }
}

=head1 hash \@H, salt, string

=cut

sub hash {
  my ($H, $key ) = @_;
  my $d = length $key;
  my $size = scalar @$H - 1;
  for (split //, $key) {
    $d = $H->[$d ^ (255 & ord($_))];
  }
  return $d;
}

=head1 false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is 1, unless you created the hash with the
option C<-no-false-positives>.

=cut

sub false_positives {
  return !exists $_[0]->[1]->{'-no-false-positives'};
}

# local testing: pb -d lib/Perfect/Hash/PearsonPP.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearsonpp")'
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(shift @ARGV, "-pearsonnp", @ARGV)
}

1;
