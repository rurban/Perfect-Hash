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

This Pearson hash variant is perfect. It uses a random pearson table
of size 256, and extends the keyspace in prime steps to find a perfect
hash starting with a load factor of 0.7 down to ~0.5, until no
collisions remain or the search times out.

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

=head1 METHODS

=head2 new $dict, @options

Computes a brute-force 8-bit Pearson hash table using the given
dictionary, given as hashref or arrayref, with fast lookup. 
It extends the keys. This generator might fail rarely, returning undef.

Honored options are:

I<-false-positives>

I<-max-time seconds> stops generating a phash at seconds and uses a
non-perfect, but still fast hash then. Default: 60 seconds.

It returns an object with \@H containing the randomized
pearson lookup table or undef if none was found.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref or arrayref, file later
  my $options = Perfect::Hash::_handle_opts(@_);
  $options->{'-max-time'} = 60 unless exists $options->{'-max-time'};
  my $max_time = $options->{'-max-time'};
  my ($keys, $values) = _dict_init($dict);
  my $size = scalar @$keys;
  my $origsize = $size;
  eval { require Math::Prime::XS; };
  if ($@) {
    # roughly prime, enough for our usage
    eval "sub is_prime { not($_[0] % 2 or $_[0] % 3 or $_[0] % 5 or $_[0] % 7) }";
  } else {
    *is_prime = \&Math::Prime::XS::is_prime;
  }

  # fixed size of 256 for @H
  my $hsize = 256;
  # extend keys to a fill-rate between 0.7 - 0.5, with size being prime
  print "origsize=$size hsize=$hsize\n" if $options->{'-debug'};
  {
    no integer;
    $size = $class->next_prime(int($origsize * 1.7));
  }
  $keys->[$size - 1] = undef; # auto-vivifies the intermediate elements

  my $maxcount = 15; # 15/5 when to stop the search. could be extended up to n!
  my ($max, $counter, $H) = (0, 0, undef);
  my $load;
  my $ph = bless [$size], $class;
  { 
    no integer;
    $load = sprintf("%.2f", $origsize / $size);
  }
  while ($max != 1) {
    # with higher load only try 5x, but under 50% try more, as this should lead to a hit
    $maxcount = $load ge "0.50" ? 5 : 25;
    # Step 1: Generate @H
    $counter = 0;
    my @H; $#H = $hsize-1;
    my $i = 0;
    $H[$_] = $i++ for 0 .. $hsize-1; # init with ordered sequence
    $H = \@H;
    $ph = bless [$size, $H], $class;

    # Step 2: shuffle @H until we get a good maxbucket, only 0 or 1
    # https://stackoverflow.com/questions/1396697/determining-perfect-hash-lookup-table-for-pearson-hash
    my $t0 = [gettimeofday];
    do {
      # this is not good. we should non-randomly iterate over all permutations
      $ph->shuffle();
      (undef, $max) = $ph->cost($keys);
      print "size=$size load=$load max=$max counter=$counter\n" if $options->{'-debug'};
      $counter++;
    } while ($max > 1 and $counter < $maxcount); # 5 or 15

    # Step 3: extend keyspace to get a higher probability of a collision-less perfect hash
    if ($max != 1) { # next round
      no integer; # for $load calc
      $size = $ph->next_prime($size+2); # extend keys to the next prime
      $load = sprintf("%0.2f", $origsize / $size);
      $keys->[$size - 1] = undef;
      last if tv_interval($t0) > $max_time;
    }
  }
  return undef if $max != 1;

  # Step 4: re-order the keys and their values
  my @newkeys; $#newkeys = $size - 1;
  my @newvalues; $#newvalues = $size - 1;
  my $i = 0;
  for my $k (@$keys) {
    my $v = $ph->hash($k);
    if (defined $v) {
      $newkeys[$v] = $k;
      $newvalues[$v] = @$values ? $values->[$i] : $i;
      print "$i: keys[$v] = $k\n" if $options->{'-debug'};
    }
    $i++;
  }
  return bless [$size, $H, \@newvalues, $options, \@newkeys], $class;
}

=head2 next_prime

Helper method to return the next prime for the given size

=cut

sub next_prime {
  my ($ph, $size) = @_;
  $size++ unless $size % 2;
  while (!is_prime($size)) {
    $size += 2;
  }
  return $size;
}

=head2 perfecthash $ph, $key

Look up a $key in the pearson hash table
and return the associated index into the initially 
given $dict.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my $v = $ph->hash($key);
  return defined $v ? $ph->[2]->[ $v ] : undef;
}

=head2 false_positives

Always returns undef. Pearson8 will not return C<-false-positives>.

=cut

sub false_positives {
  return undef;
}

=head2 save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=cut

#sub _old_save_c {
#  my $ph = shift;
#  require Perfect::Hash::C;
#  my ($fileprefix, $base) = Perfect::Hash::C::_save_c_header($ph, @_);
#  my $H;
#  open $H, ">>", $fileprefix.".h" or die "> $fileprefix.h @!";
#  print $H "
#static unsigned char $base\[] = {
#";
#  Perfect::Hash::C::_save_c_array(4, $H, $ph->[1]);
#  print $H "};\n";
#  close $H;
#
#  my $FH = Perfect::Hash::C::_save_c_funcdecl($ph, $fileprefix, $base);
#  # non-binary only so far:
#  print $FH "
#    unsigned h = 0;
#    for (int c = *s++; c; c = *s++) {
#        h = $base\[h ^ c];
#    }
#    return h;
#}
#";
#  close $FH;
#}

# local testing: pb -d lib/Perfect/Hash/Pearson8.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearson8")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearson8", @ARGV)
}

1;
