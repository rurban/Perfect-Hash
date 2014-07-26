package Perfect::Hash::PearsonPP;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use integer;
our @ISA = qw(Perfect::Hash);

=head1 DESCRIPTION

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

Optimal for 5-255 keys

=head1 new $dict, options

Computes a perfect hash table using the given dictionary,
given as hashref or arrayref, with fast lookup.

Honored options are: I<-no-false-positives>

It returns an object with @H containing the randomized
pearson lookup table of size 255.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref or arrayref, file later
  my %options = map {$_ => 1 } @_;
  my $size;
  my $olddict;
  if (ref $dict eq 'ARRAY') {
    my $i = 0;
    my %dict = map {$_ => $i++} @$dict;
    $size = scalar @$dict;
    $olddict = $dict;
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
      $olddict = \@arr;
    }
  }
  my $last = $size-1;

  # Step 1: Generate @H
  my @H; $#H = 255;
  my $i = 0;
  $H[$_] = $i++ for 0 .. 255; # init with ordered sequence
  my $H = \@H;
  my $maxbuckets = $last > 255 ? $last / 255 : 1;
  my $buckets = 0;
  my @N = ();
  my $counter = 0;
  $N[$_] = 0 for 0..255;
  # Step 2: shuffle H@ until we get a good maxbucket
  do {
    shuffle($H);
    for (0..$last) {
      my $h = hash($H, 0, $olddict->[$_]);
      $N[$h]++;
      $buckets = $N[$h] if $buckets > $N[$h];
    }
    $counter++;
  } while $buckets > $maxbuckets or $counter > $last; # $n!
  die "No pearson ph found" if $counter > $last;

  if (exists $options{'-no-false-positives'}) {
    return bless [$H, \%options, $olddict], $class;
  } else {
    return bless [$H, \%options], $class;
  }
}

sub shuffle {
  # the "Knuth Shuffle", a random shuffle
  my $H = $_[0];
  my $last = scalar(@$H) - 1;
  for my $i (0 .. $last) {
    my $tmp = $_[0]->[$i];
    my $j = $i + int rand($last-$i);
    $_[0]->[$i]= $_[0]->[$j];
    $_[0]->[$j] = $tmp;
  }
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
  my $v = hash($H, 0, $key);
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
  my ($H, $d, $key ) = @_;
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
  return !exists $_[0]->[2]->{'-no-false-positives'};
}

# local testing: pb -d lib/Perfect/Hash/PearsonPP.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearsonpp")'
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(shift @ARGV, "-pearsonpp", @ARGV)
}

1;
