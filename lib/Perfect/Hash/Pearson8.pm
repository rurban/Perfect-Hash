package Perfect::Hash::Pearson8;
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::Pearson;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash::Pearson Perfect::Hash Perfect::Hash::C);
our $VERSION = '0.01';

=head1 DESCRIPTION

A Pearson hash is generally not perfect, but generates one of the
fastest lookups.  This version is limited to max. 255 keys and thus
creates a perfect hash.

Optimal for 5-250 keys.

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

=head1 METHODS

=head2 new $dict, @options

Computes a brute-force 8-bit Pearson hash table using the given
dictionary, given as hashref or arrayref, with fast lookup.  This
generator might fail, returning undef.

Honored options are:

I<-no-false-positives>

I<-max-time seconds> stops generating a phash at seconds and uses a
non-perfect, but still fast hash then. Default: 60 seconds.

It returns an object with \@H containing the randomized
pearson lookup table or undef if none was found.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref or arrayref, file later
  my $max_time = grep { $_ eq '-max-time' and shift } @_;
  $max_time = 60 unless $max_time;
  my %options = map {$_ => 1 } @_;
  $options{'-max-time'} = $max_time;
  my ($keys, $values) = _dict_init($dict);
  my $size = scalar @$keys;
  my $last = $size-1;
  if ($last > 255) {
    warn "cannot create perfect 8-bit pearson hash for $size entries > 255\n";
    # would need a 16-bit pearson or any-size pearson (see -pearson)
    return;
  }

  # Step 1: Generate @H
  # round up to ending 1111's
  my $hsize = 255;
  #print "size=$size hsize=$hsize\n";
  # TODO: bitvector string with vec
  my @H; $#H = $hsize;
  my $i = 0;
  $H[$_] = $i++ for 0 .. $hsize; # init with ordered sequence
  my $H = \@H;
  my $maxcount = 3 * $last; # when to stop the search. could be n!
  # Step 2: shuffle @H until we get a good maxbucket, only 0 or 1
  # https://stackoverflow.com/questions/1396697/determining-perfect-hash-lookup-table-for-pearson-hash
  my ($max, $counter);
  my $t0 = [gettimeofday];
  do {
    # this is not good. we should non-randomly iterate over all permutations
    shuffle($H);
    (undef, $max) = cost($H, $keys);
    $counter++;
  } while ($max > 1 and $counter < $maxcount and tv_interval($t0) < $max_time); # $n!
  return if $max != 1;

  if (exists $options{'-no-false-positives'}) {
    return bless [$size, $H, \%options, $keys], $class;
  } else {
    return bless [$size, $H, \%options], $class;
  }
}

=head2 perfecthash $obj, $key

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
  my $v = hash($ph->[1], $key, $ph->[0]);
  # -no-false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the exists $ph->[1]->{-no-false-positives} check for now
  if ($ph->[3]) {
    return ($ph->[3]->[$v] eq $key) ? $v : undef;
  } else {
    return $v;
  }
}

=head2 false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is 1, unless you created the hash with the
option C<-no-false-positives>.

=cut

sub false_positives {
  return !exists $_[0]->[2]->{'-no-false-positives'};
}

=head2 save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=cut

sub save_c {
  my $ph = shift;
  require Perfect::Hash::C;
  my ($fileprefix, $base) = Perfect::Hash::C::_save_c_header($ph, @_);
  my $H;
  open $H, ">>", $fileprefix.".h" or die "> $fileprefix.h @!";
  print $H "
static unsigned char $base\[] = {
";
  Perfect::Hash::C::_save_c_array(4, $H, $ph->[1]);
  print $H "};\n";
  close $H;

  my $FH = Perfect::Hash::C::_save_c_funcdecl($ph, $fileprefix, $base);
  # non-binary only so far:
  print $FH "
    unsigned h = 0;
    for (int c = *s++; c; c = *s++) {
        h = $base\[h ^ c];
    }
    return h;
}
";
  close $FH;
}

# local testing: pb -d lib/Perfect/Hash/Pearson8.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearson8")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearson8", @ARGV)
}

1;
