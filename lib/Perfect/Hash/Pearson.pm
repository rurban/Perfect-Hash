package Perfect::Hash::Pearson;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use integer;
use bytes;

use Exporter 'import';
our @ISA = qw(Perfect::Hash Perfect::Hash::C Exporter);
our @EXPORT = qw(hash shuffle cost collisions);

=head1 DESCRIPTION

A Pearson hash is generally not perfect, but generates fast lookups on
small 8bit machines.  This version generates arbitrary sized pearson
lookup tables and thus should be able to find a perfect hash, but
success is very unlikely. The generated lookup might be however still
pretty fast for <100.000 keys.

From: Communications of the ACM
Volume 33, Number 6, June, 1990
Peter K. Pearson
"Fast hashing of variable-length text strings"

WARNING: This version is still instable.

=head1 METHODS

=head2 new $dict, @options

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
  my $i = 8; # start with 256 to avoid % $hsize in hash
  while (2**$i++ < $size) {}
  my $hsize = 2**($i-1) - 1;
  print "size=$size hsize=$hsize\n" if $options{'-debug'};
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
    print "$counter sum=$sum, max=$max\n" if $options{'-debug'};
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
    print "list of collisions: sum=$sum, maxdepth=$max\n" if $options{'-debug'};
    $C = collisions($H, $keys, $values);
  }

  if (exists $options{'-no-false-positives'}) {
    return bless [$size, $H, $C, \%options, $keys], $class;
  } else {
    return bless [$size, $H, $C, \%options], $class;
  }
}

sub option {
  return $_[0]->[3]->{$_[1]};
}

=head2 option $ph

Access the option hash in $ph

=head2 shuffle

Helper method to calculate a pearson permutation table via Knuth Random Shuffle.

=cut

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

=head2 cost

Helper method to calculate the cost for the current pearson permutation table.

=cut

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

=head2 collisions

Helper method to gather arrayref of arrayrefs of all collisions.

=cut

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

=head2 hash \@H, salt, string

=cut

sub hash {
  my ($H, $key, $size ) = @_;
  my $d = 0;
  my $hsize = scalar @$H;
  if ($hsize == 256) {
    for my $c (split "", $key) {
      $d = $H->[$d ^ ord($c)];
    }
  } else {
    for my $c (split "", $key) {
      $d = $H->[($d ^ ord($c)) % $hsize];
    }
  }
  return $d % $size;
}

=head2 perfecthash $obj, $key

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

=head2 false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is 1, unless you created the hash with the
option C<-no-false-positives>.

=cut

sub false_positives {
  return !exists $_[0]->[3]->{'-no-false-positives'};
}

=head2 save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=head2 save_c $ph

Generate C code for all 3 Pearson classes

=cut

sub save_c {
  my $ph = shift;
  my $C = $ph->[2];
  require Perfect::Hash::C;
  Perfect::Hash::C->import();
  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  print $FH "#include <string.h>\n" if @$C;
  print $FH $ph->c_hash_impl($base);
  print $FH $ph->c_funcdecl($base)." {";
  my $size = $ph->[0];
  my $H = $ph->[1];
  my $hsize = scalar @$H;
  my $htype = "char";
  $htype = "int" if $hsize > 256;
  $htype = "long" if $hsize > 65537;
  print $FH "
    long h = 0;
    const char *key = s;
    static unsigned $htype $base\[] = {\n";
  _save_c_array(8, $FH, $H, "%3d");
  print $FH "    };\n";
  print $FH "    /* collisions */";
  my $collisions;
  my $i = 0;
  for my $coll (@$C) {
    if ($coll and @$coll) {
      $collisions++;
      print $FH "
    static const char *Ck_$i\[] = {";
      my @ci = map { $_->[0] } @$coll;
      _save_c_array(0, $FH, \@ci, "\"%s\"");
      print $FH " };";
      print $FH "
    static const int   Cv_$i\[] = {";
      my @cv = map { $_->[1] } @$coll;
      _save_c_array(0, $FH, \@cv, "%d");
      print $FH " };";
    }
    $i++;
  }
  if ($collisions) {
    $i = 0;
    print $FH "
    static const char *Ck[] = { ";
    for my $coll (@$C) {
      if ($coll and @$coll) {
        print $FH "
        (void*)&Ck_$i, ";
      } else {
        print $FH "0, ";
      }
      $i++;
    }
    print $FH "};";
    $i = 0;
    print $FH "
    static const int *Cv[] = { ";
    for my $coll (@$C) {
      if ($coll and @$coll) {
        print $FH "
        (void*)&Cv_$i, ";
      } else {
        print $FH "0, ";
      }
      $i++;
    }
    print $FH "};";
    print $FH "
    static const int Cs[] = { ";
    $i = 0;
    for my $coll (@$C) {
      if ($coll and @$coll) {
        print $FH scalar @$coll,", ";
      } else {
        print $FH "0, ";
      }
      $i++;
    }
    print $FH "};";
  }
  if (!$ph->false_positives) { # store keys
    my $keys = $ph->[4];
    print $FH "
    /* keys */
    static const char* K[] = {\n";
    _save_c_array(8, $FH, $keys, "\"%s\"");
    print $FH "    };";
  }
  if ($ph->option('-nul')) {
    print $FH "
    int i;
    for (i=0; i<l; i++) {";
    if (ref $ph eq 'Perfect::Hash::Pearson') {
      print $FH "
        h = $base\[(h ^ s[i]) % $hsize];";
    } else {
      print $FH "
        h = $base\[h ^ s[i]];";
    }
    print $FH "
    }";
  } else {
    print $FH "
    unsigned char c;
    for (c=*s++; c; c=*s++) {";
    if (ref $ph eq 'Perfect::Hash::Pearson') {
      print $FH "
        h = $base\[(h ^ c) % $hsize];";
    } else {
      print $FH "
        h = $base\[h ^ c];";
    }
    print $FH "
    }";
  }
  print $FH "
    h = h % $size;" if $hsize != $size;
  if ($collisions) {
      print $FH "
    if (Ck[h]) {
      const char **ck = (const char **)Ck[h];
      int i = 0;
      for (; i < Cs[h]; i++) {
        if (!strcmp(ck[i], key)) return Cv[h][i];
      }
    }";
  }
  if (!$ph->false_positives) { # check keys
    if ($ph->option('-nul')) {
      print $FH "
    if (memcmp(K[h], key, l)) h = -1;";
    } else {
      print $FH "
    if (strcmp(K[h], key)) h = -1;";
    }
  }
  print $FH "
    return h;
}
";
  close $FH;
}

=head2 c_hash_impl $ph, $base

String for C code for the hash function, depending on C<-nul>.

=cut

sub c_hash_impl {""}

=head2 save_xs $ph

Generate XS code for all 3 Pearson classes

=cut

sub save_xs { die "save_xs NYI" }

# local testing: pb -d lib/Perfect/Hash/Pearson.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearson")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearson", @ARGV)
}

1;
