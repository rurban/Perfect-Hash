package Perfect::Hash::PearsonNP;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::Pearson;
our @ISA = qw(Perfect::Hash::Pearson);
use integer;
use bytes;

=head1 DESCRIPTION

Generate non-perfect pearson hash with static binary tree
collision resolution.

Good for 5-100.000 keys.

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

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
  my $class = shift or die;
  my $dict = shift; # hashref or arrayref or filename
  my $max_time = grep { $_ eq '-max-time' and shift } @_;
  $max_time = 60 unless $max_time;
  my %options = map {$_ => 1 } @_;
  $options{'-max-time'} = $max_time;
  my ($keys, $values) = _dict_init($dict);
  my $size = scalar @$keys;
  my $last = $size-1;

  # Step 1: Generate @H
  # TODO: bitvector string with vec
  my @H; $#H = 255;
  my $i = 0;
  $H[$_] = $i++ for 0 .. 255; # init with ordered sequence
  my $H = \@H;
  # expected max: birthday paradoxon
  my ($C, @best, $sum, $maxsum, $max, $counter, $maxcount);
  $maxcount = 30; # when to stop the search. exhaustive is 255!
  # Step 2: shuffle @H until we get a good max, only 0 or 1
  # https://stackoverflow.com/questions/1396697/determining-perfect-hash-lookup-table-for-pearson-hash
  my $t0 = [gettimeofday];
  do {
    # this is not good. we should non-randomly iterate over all permutations
    shuffle($H);
    ($sum, $max) = cost($H, $keys);
    $counter++;
    #print "$counter sum=$sum, max=$max\n";
    if (!defined($maxsum) or $sum < $maxsum or $max == 1) {
      $maxsum = $sum;
      @best = @$H;
    }
  } while ($max > 1 and $counter < $maxcount and tv_interval($t0) < $max_time); # $n!

  if ($max > 1) {
    @H = @best;
    $H = \@H;
    ($sum, $max) = cost($H, $keys);
    # Step 3: Store collisions as no perfect hash was found
    print "list of collisions: sum=$sum, maxdepth=$max\n"
      if $options{'-debug'};
    $C = collisions($H, $keys, $values);
  }

  if (!exists $options{'-false-positives'}) {
    return bless [$size, $H, $C, \%options, $keys], $class;
  } else {
    return bless [$size, $H, $C, \%options], $class;
  }
}

=head2 perfecthash $obj, $key

Look up a $key in the pearson hash table
and return the associated index into the initially 
given $dict.

Note that the hash is probably not perfect.

Without C<-false-positives> it checks if the index is correct,
otherwise it will return undef.
With C<-false-positives>, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my $H = $ph->[1];
  my $C = $ph->[2];
  my $v = hash($H, $key, $ph->[0]);
  # check collisions. todo: binary search
  if ($C and $C->[$v]) {
    if (@{$C->[$v]} > 1) {
      print "check ".scalar @{$C->[$v]}." collisions for $key\n" if $ph->[3]->{-debug};
      for (@{$C->[$v]}) {
        if ($key eq $_->[0]) {
          $v = $_->[1];
          last;
        }
      }
    } else {
      $v = $C->[$v]->[0];
    }
  }
  # -false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the !exists $ph->[2]->{-false-positives} check for now
  if ($ph->[4]) {
    return ($ph->[4]->[$v] eq $key) ? $v : undef;
  } else {
    return $v;
  }
}

=head2 false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>.

=cut

sub false_positives {
  return exists $_[0]->[3]->{'-false-positives'};
}

# local testing: pb -d lib/Perfect/Hash/PearsonPP.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearsonpp")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearsonnp", @ARGV)
}

1;
