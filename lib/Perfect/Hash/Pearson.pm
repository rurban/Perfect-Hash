package Perfect::Hash::Pearson;
our $VERSION = '0.01';
#use coretypes;
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::C;
use integer;
use bytes;

use Exporter 'import';
our @ISA = qw(Perfect::Hash Exporter Perfect::Hash::C);
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

=head1 METHODS

=head2 new $dict, @options

Computes a brute-force n-bit Pearson hash table using the given
dictionary, given as hashref or arrayref, with fast lookup.

Honored options are:

I<-false-positives> do not save keys, may only be used with existing keys.

I<-max-time seconds> stops generating a phash at seconds and uses a
non-perfect, but still fast hash then. Default: 60s.

It returns an object with @H containing the randomized
pearson lookup table.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref or arrayref or filename
  my $options = Perfect::Hash::_handle_opts(@_);
  $options->{'-max-time'} = 60 unless exists $options->{'-max-time'};
  my $max_time = $options->{'-max-time'};
  my ($keys, $values) = _dict_init($dict);
  my $size = scalar @$keys;
  my $last = $size-1;

  # Step 1: Generate @H the pearson table with varying size.
  # Round up to 2 complements, with ending 1111's.
  # TODO: The other approach, extending keys to a fill-rate of 50% and
  # a prime size should work better, See Pearson8
  my $i = 8; # start with 255 to avoid % $hsize in hash
  while (2**$i++ < $size) {}
  my $hsize = 2**($i-1);
  print "size=$size hsize=$hsize\n" if $options->{'-debug'};
  my @H; $#H = $hsize-1;
  $i = 0;
  $H[$_] = $i++ for 0 .. $hsize-1; # init with ordered sequence
  my $H = \@H;
  my $ph = bless [$size, $H], $class;

  # Step 2: shuffle @H until we get a good maxbucket, only 0 or 1
  # https://stackoverflow.com/questions/1396697/determining-perfect-hash-lookup-table-for-pearson-hash
  # expected max: birthday paradoxon
  my ($C, $best, $sum, $maxsum, $max, $maxdepth, $counter, $maxcount);
  $maxcount = $last; # when to stop the search. should be $last !
  # we should rather set a time-limit like 1 min.
  my $t0 = [gettimeofday];
  do {
    # this is not good. we should non-randomly iterate over all permutations
    $ph->shuffle();
    ($sum, $max) = $ph->cost($keys);
    $counter++;
    print "$counter sum=$sum, max=$max\n" if $options->{'-debug'};
    if (!defined($maxsum) or $sum < $maxsum or $max == 1 or ($sum == $maxsum and $max < $maxdepth)) {
      $maxsum = $sum;
      $maxdepth = $max;
      $best = $ph;
    }
  } while ($max > 1 and $counter < $maxcount and tv_interval($t0) < $max_time);

  if ($max > 1) {
    #($sum, $max) = cost($H, $keys);
    # Step 3: Store collisions as no perfect hash was found
    print "list of collisions: sum=$maxsum, maxdepth=$maxdepth\n" if $options->{'-debug'};
    $ph = $best;
    $C = $ph->collisions($keys, $values);
  }

  if (!exists $options->{'-false-positives'}) {
    return bless [$size, $H, $C, $options, $keys], $class;
  } else {
    return bless [$size, $H, $C, $options], $class;
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
  my $ph = $_[0];
  my $H = $ph->[1];
  my $last = scalar(@$H)-1;
  #warn $last if $last != 255;
  for my $i (0 .. $last) {
    my $tmp = $H->[$i];
    my $j = $i + int rand($last-$i); #warn $j if $j > $last;
    $H->[$i]= $H->[$j];
    $H->[$j] = $tmp;
  }
  #warn $last," ",$H->[$last-1]," ",$H->[$last],"\n";
  #warn $H->[$last+1], $last if scalar(@$H) != 256;
  #delete $H->[$last+1];
}

=head2 cost

Helper method to calculate the cost for the current pearson permutation table.

=cut

sub cost {
  my ($ph, $keys) = @_;
  my $size = $ph->[0];
  my $H = $ph->[1];
  my @N = (); $#N = scalar(@$H) - 1;
  $N[$_] = 0 for 0..$#N;
  my ($sum, $max) = (0, 0);
  for (@$keys) {
    my $h = $ph->hash($_);
    next unless defined $h;
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
  my ($ph, $keys, $values) = @_;
  my $size = $ph->[0];
  my $H = $ph->[1];
  my @C = (); $#C = $size - 1;
  $C[$_] = [] for 0..$#C;
  unless (@$values) { $values = [0 .. $size-1]; }
  my $i = 0;
  for (@$keys) {
    my $h = $ph->hash($_); # e.g. a=>1 b=>11 c=>111
    next unless defined $h;
    push @{$C[$h]}, [$_, $values->[$i]];
    $i++;
  }
  @C = map { scalar @$_ > 1
               ? $_
               : scalar @$_ == 1
                 ? [ $_->[0]->[1] ]
                 : undef } @C;
  return \@C;
}

=head2 hash salt, string

=cut

sub hash {
  my ($ph, $key ) = @_;
  return undef unless defined $key;
  my $size = $ph->[0];
  my $H = $ph->[1];
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

Look up a $key in the pearson hash table and return the associated
index into the initially given $dict.

Note that the hash is probably not perfect.

Without C<-false-positives> it checks if the index is correct,
otherwise it will return undef.
With C<-false-positives>, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my $C = $ph->[2];
  my $h = $ph->hash($key);
  return undef unless defined $h;
  my $v;
  if (defined $C->[$h]) {
    if (@{$C->[$h]} > 1) {
      #print "check ".scalar @{$C->[$h]}." collisions for $key\n" if $ph->[3]->{-debug};
      for (@{$C->[$h]}) {
        if ($key eq $_->[0]) {
          $v = $_->[1];
          last;
        }
      }
    } else {
      $v = $C->[$h]->[0];
    }
  }
  # -false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the !exists $ph->[2]->{-false-positives} check for now
  # XXX only correct if values start with 0 (the $v'd key)
  if (defined($v) and $ph->[4]) {
    return ($ph->[4]->[$v] eq $key) ? $v : undef;
  } else {
    return $v;
  }
}

=head2 false_positives

Returns 1 if the hash might return false positives, i.e. will return
the index of an existing key when you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>.

=cut

sub false_positives {
  return exists $_[0]->[3]->{'-false-positives'};
}

=head2 save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=head2 save_c $ph

Generate C code for all 3 Pearson classes

=cut

sub save_c {
  my $ph = shift;
  my $C = $ph->[2];
  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  # print $FH "#include <string.h>\n" if @$C or !$ph->option('-nul');
  if (!$ph->option('-nul')) {
    # XXX check for ASAN or just use a if not
    print $FH "#define _min(a,b) (a < b) ? (a) : (b)\n";
  }
  print $FH $ph->c_hash_impl($base);
  print $FH $ph->c_funcdecl($base)." {";
  my $size = $ph->[0];
  my $H = $ph->[1];
  my $hsize = scalar @$H;
  my $htype = u_csize($hsize);
  print $FH "
    const unsigned char* su = (const unsigned char*)s;";
  print $FH "
    int l = s ? strlen(s) : 0;" unless $ph->option('-nul');
  print $FH "
    long h = 0;
    long v;
    static $htype $base\[] = {\n";
  _save_c_array(8, $FH, $H, "%3d");
  print $FH "    };";
  my ($maxcoll, $collisions, $i) = (0,0,0);
  if (ref $ph ne 'Perfect::Hash::Pearson8') {
    print $FH "    /* collisions: keys and values */";
    for my $coll (@$C) {
      if ($coll) {
        if (scalar(@$coll) > 1) {
          $maxcoll = scalar(@$coll) if $maxcoll < scalar(@$coll);
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
        } elsif (scalar(@$coll) == 1) {
          print $FH "
    static const int   Cv_$i\[] = {",$coll->[0],"};";
        }
      }
      $i++;
    }
  }
  my $ctype = u_csize($maxcoll);
  if ($collisions) {
    $i = 0;
    print $FH "
    /* collision keys */
    static const char *Ck[] = { ";
    for my $coll (@$C) {
      if ($coll and scalar(@$coll) > 1) {
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
    /* collision values and direct values */
    static const int *Cv[] = { ";
    for my $coll (@$C) {
      if ($coll and scalar(@$coll) > 0) {
        print $FH "
      (void*)&Cv_$i, ";
      } else {
        print $FH "0, ";
      }
      $i++;
    }
    print $FH "};";
    # XXX Cs should not be needed, but is
    print $FH "
    /* size of collisions */
    static const $ctype Cs[] = { ";
    $i = 0;
    for my $coll (@$C) {
      if ($coll and scalar(@$coll)) {
        print $FH scalar(@$coll),", ";
      } else {
        print $FH "0, ";
      }
      $i++;
    }
    print $FH "};";
  }
  if (!$ph->false_positives) { # store keys
    my $keys = $ph->[4];
    if ($ph->option('-pic')) {
      c_stringpool($FH, $keys);
    } else {
      print $FH "
    /* keys */
    static const char* keys[] = {\n";
      _save_c_array(8, $FH, $keys, "\"%s\"");
      print $FH "    };";
    }
    if (ref $ph eq 'Perfect::Hash::Pearson8') {
      my $valtype = u_csize(scalar @$C);
      print $FH "
    /* values */
    static $valtype values[] = {\n";
      _save_c_array(8, $FH, $C, "%d");
      print $FH "    };";
    }
  }
  if (ref $ph eq 'Perfect::Hash::Pearson32') {
    print $FH "
    unsigned int *hi = (unsigned int *)&",$base,"[0];
    int i;
    for (i=0; i < l/4; i += 4, su += 4) {
      h = hi[ ((unsigned int)h ^ *(unsigned int*)su) % 64];
    }
    for (; i < l; i++, su++) {
      h = $base\[ (($htype)h ^ *su) % 256 ];
    }";
  }
  elsif (ref $ph eq 'Perfect::Hash::Pearson16') {
    print $FH "
    unsigned short hs;
    int i;
    for (i = 0; i < (l % 2 ? l -1 : l); i++) {
      hs = $base\[ (unsigned short)(hs ^ *(unsigned short*)su++) ];
    }
    if (l % 2)
      hs = $base\[ (unsigned short)(hs ^ su[l-1]) ];
    h = hs;";
  } elsif ($ph->option('-nul')) {
    print $FH "
    int i;
    for (i=0; i<l; i++) {";
      if (ref $ph eq 'Perfect::Hash::Pearson') {
        print $FH "
        h = $base\[(($htype)h ^ su[i]) % $hsize];";
      } else {
        print $FH "
        h = $base\[($htype)h ^ su[i]];";
      }
      print $FH "
    }";
  } else {
    print $FH "
    unsigned char c;
    for (c=*su++; c; c=*su++) {";
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
  if (ref $ph eq 'Perfect::Hash::Pearson8') {
    print $FH "
    return keys[h] ? values[h] : -1;";
  } else {
    print $FH "
    v = h;";
  }
  if ($collisions) {
      print $FH "
    if (Cs[h] > 1) {
      const char **ck = (const char **)Ck[h];
      int i = 0;
      for (; i < Cs[h]; i++) {";
      # ck[i] is not known in advance. +1 to include the final \0
      my $l = $ph->option('-nul') ? "l+1" : "1+(_min(l, strlen(ck[i])))";
      print $FH "
        if (!memcmp(ck[i], s, $l)) return Cv[h][i];";
      print $FH "
      }
    }
    else if (Cs[h] == 1) {
      v = Cv[h][0];
    }";
  }
  if (!$ph->false_positives) { # check keys
    # we cannot use memcmp_const_str nor memcmp_const_len because we don't know K[h] nor l
    if ($ph->option('-pic')) {
      print $FH "
    if (l == 0) { return -1; }
    else {
      register int o = keys[h];
      if (o >= 0) {
        register const char *st = o + stringpool;
        if (*st != *s || memcmp(s + 1, st + 1, l-1))
          v = -1;
      }
    }";
    } else {
      my $l = $ph->option('-nul') ? "l" : "_min(l, strlen(keys[h]))";
      print $FH "
    if (l == 0 || memcmp(keys[h], s, $l)) v = -1;";
    }
  }
  print $FH "
    return v;
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


sub _test_tables {
  my $ph = shift; #__PACKAGE__->new("examples/words20", qw(-debug));
  $ph->[3]->{'-debug'} = 1;
  my $size = $ph->[0];
  my $H = $ph->[1];
  my $C = $ph->[2];
  my $keys = $ph->[4];
  for (0 .. scalar(@$keys)-1) {
    my $k = $keys->[$_];
    next unless defined $k;
    my $v = $ph->hash($k);
    my $h = $v;
    if ($C and defined $C->[$h]) {
      #print "check ".scalar @{$C->[$h]}." collisions for $k\n";
      if (ref $C->[$h]) {
        if (@{$C->[$h]} > 1) {
          for (@{$C->[$h]}) {
            if ($k eq $_->[0]) {
              $v = $_->[1];
              last;
            }
          }
        } else {
          $v = $C->[$h]->[0];
        }
      }
      else {
        $v = $C->[$h]; # Pearson8 \@newvalues
      }
    }
    printf "%2d: ph=%2s   h(%2d)=%2d => %2d  %s %s\n",
      $_, $ph->perfecthash($k),
      $_, $h, $v, $k,
      ($C and $C->[$h] and ref $C->[$h] and @{$C->[$h]} > 1)
        ? "(".join(",",map{$_->[0]}@{$C->[$h]}).")" : $v
  }
}

# local testing: pb -d lib/Perfect/Hash/Pearson.pm examples/words20
# or just: pb -d -MPerfect::Hash -e'new Perfect::Hash([split/\n/,`cat "examples/words20"`], "-pearson")'
unless (caller) {
  &Perfect::Hash::_test(shift @ARGV, "-pearson", @ARGV)
}

1;
