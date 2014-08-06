package Perfect::Hash::HanovPP;
#use coretypes;
BEGIN {$int::x = $num::x = $str::x}
use strict;
#use warnings;
use Perfect::Hash;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);
our $VERSION = '0.01';

=head1 DESCRIPTION

Perl variant of the python "Easy Perfect Minimal Hashing" epmh.py
By Steve Hanov. Released to the public domain.
http://stevehanov.ca/blog/index.php?id=119

Very simple and inefficient, needing O(2n) space.

Based on:
Edward A. Fox, Lenwood S. Heath, Qi Fan Chen and Amjad M. Daoud, 
"Practical minimal perfect hash functions for large databases", CACM, 35(1):105-121

This version is stable and relatively fast even for bigger dictionaries.

=head1 new $dict, @options

Computes a minimal perfect hash table using the given dictionary,
given as hashref, arrayref or filename.

Honored options are: I<-no-false-positives>

It returns an object with a list of [\@G, \@V, ...].
@G contains the intermediate table of seeds needed to compute the
index of the value in @V.  @V contains the values of the dictionary.

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
  my @G; $#G = $size; @G = map {0} (0..$last);
  my @V; $#V = $last;

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
    my int $d = 1;
    my int $item = 0;
    my %slots;

    # Repeatedly try different values of $d (the seed) until we find a hash function
    # that places all items in the bucket into free slots.
    while ($item < scalar(@bucket)) {
      my $slot = hash($bucket[$item], $d) % $size;
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

  if (exists $options{'-no-false-positives'}) {
    return bless [\@G, \@V, \%options, $keys], $class;
  } else {
    return bless [\@G, \@V, \%options], $class;
  }
}

sub option {
  return $_[0]->[2]->{$_[1]};
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
  my $h = hash($key, 0) % $size;
  my $d = $G->[$h];
  my $v = $d < 0
        ? $V->[- $d-1]
        : $d == 0
          ? $V->[$h]
          : $V->[hash($key, $d) % $size];
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

The default is 1, unless you created the hash with the option
C<-no-false-positives>, which increases the required space from
2n to B<3n>.

=cut

sub false_positives {
  return !exists $_[0]->[2]->{'-no-false-positives'};
}

=head1 hash string, [seed]

pure-perl FNV-1 hash function as in http://isthe.com/chongo/tech/comp/fnv/

=cut

sub hash {
  my str $str = shift;
  my int $d = shift || 0x01000193;
  for my $c (split//, $str) {
    $d = ( ($d * 0x01000193) ^ ord($c) ) & 0xffffffff;
  }
  return $d
}

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=cut

# for HanovPP and Urban
sub save_c {
  my $ph = shift;
  require Perfect::Hash::C;
  Perfect::Hash::C->import();
  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  print $FH $ph->c_hash_impl($base);
  print $FH $ph->c_funcdecl($base)." {";

  my ($G, $V) = ($ph->[0], $ph->[1]);
  my $size;
  if (ref $ph eq 'Perfect::Hash::Urban') {
    my (@V, @G);
    my $bits = $ph->[1];
    $size = 4 * length($G) / $bits;
    my $voff = $size;
    for my $i (0..$size-1) {
      my $d = vec($G, $i, $bits);
      $d = ($d - (1<<$bits)) if $d >= 1<<($bits-1);
      $G[$i] = $d;
    }
    # TODO: if @V contains only int indices
    for my $i (0..$size-1) {
      $V[$i] = vec($G, $i+$size, $bits);
    }
    $G = \@G;
    $V = \@V;
  } else {
    $size = scalar(@$G);
  }
  print $FH "
    int d;
    unsigned h;
    unsigned long v;
    /* hash indices, direct < 0, indirect > 0 */
    static const signed int G[] = {
";
  _save_c_array(8, $FH, $G, "%3d");
  print $FH "    };";
  print $FH "
    /* values */
    static const signed long V[] = {
";
  _save_c_array(8, $FH, $V, "%3d");
  print $FH "    };";
  if (!$ph->false_positives) { # store keys
    my $keys = $ph->[3];
    print $FH "
    /* keys */
    static const char* K[] = {
";
    _save_c_array(8, $FH, $keys, "\"%s\"");
    print $FH "    };";
  }
  if ($ph->option('-nul')) {
    print $FH "
    h = $base\_hash_len(0, s, l) % $size;
    d = G[h];
    v = d < 0
        ? V[-d-1]
        : g == 0
          ? V[h]
          : V[$base\_hash_len(d, s, l) % $size];
";
  } else {
    print $FH "
    h = $base\_hash(0, s) % $size;
    d = G[h];
    v = d < 0
        ? V[-d-1]
        : d == 0
          ? V[h]
          : V[$base\_hash(d, s) % $size];
";
  }
  if (!$ph->false_positives) { # check keys
    if ($ph->option('-nul')) {
      print $FH "
    if (strncmp(K[v],s,l)) v = -1;
";
    } else {
      print $FH "
    if (strcmp(K[v],s)) v = -1;
";
    }
  }
  print $FH "
    return v;
}
";
  close $FH;
}

sub c_hash_impl {
  my ($ph, $base) = @_;
  if ($ph->option('-nul')) {
    return "
/* FNV algorithm from http://isthe.com/chongo/tech/comp/fnv/ */
static inline
unsigned $base\_hash_len (unsigned d, const char *s, const int l) {
    unsigned char c = *s;
    int i = 0;
    if (!d) d = 0x01000193;
    for (; i < l; i++) {
        d = ((d * 0x01000193) ^ *s++) & 0xffffffff;
    }
    return d;
}
";
  } else {
    return "
/* FNV algorithm from http://isthe.com/chongo/tech/comp/fnv/ */
static inline
unsigned $base\_hash (unsigned d, const char *s) {
    unsigned char c;
    if (!d) d = 0x01000193;
    for (c = *s++; c; c = *s++) {
        d = ((d *  0x01000193) ^ c) & 0xffffffff;
    }
    return d;
}
";
  }
}

=back

=cut

sub _test_tables {
  my $ph = __PACKAGE__->new("examples/words20",qw(-debug -no-false-positives));
  my $keys = $ph->[3];
  # bless [\@G, \@V, \%options, $keys], $class;
  my $G = $ph->[0];
  my $V = $ph->[1];
  for (0..19) {
    my $k = $keys->[$_];
    my $d = $G->[$_] < 0 ? 0 : $G->[$_];
    printf "%2d: ph=%2d   G[%2d]=%3d  V[%2d]=%3d   h(%2d,%d)=%2d %s\n",
      $_,$ph->perfecthash($k),
      $_,$G->[$_],$_,$V->[$_],
      $_,$d,hash($k,$d)%20,
      $k;
  }
}

# local testing: p -d -Ilib lib/Perfect/Hash/HanovPP.pm examples/words20
unless (caller) {
  &Perfect::Hash::_test(@ARGV)
}

1;
