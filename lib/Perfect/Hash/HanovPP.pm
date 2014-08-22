package Perfect::Hash::HanovPP;
#use coretypes;
BEGIN {$int::x = $num::x = $str::x} # for B::CC type optimizations
use strict;
#use warnings;
use Perfect::Hash;
#use Perfect::Hash::C;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash);
our $VERSION = '0.01';

=head1 DESCRIPTION

Perl variant of the python "Easy Perfect Minimal Hashing" epmh.py
By Steve Hanov. Released to the public domain.
http://stevehanov.ca/blog/index.php?id=119

This version is stable and relatively fast even for bigger dictionaries.
Very simple and size-inefficient, needing O(2n) space,
but creates pretty fast hashes, independent of any external library.

Based on:
Edward A. Fox, Lenwood S. Heath, Qi Fan Chen and Amjad M. Daoud, 
"Practical minimal perfect hash functions for large databases", CACM, 35(1):105-121

=head1 METHODS

=over

=item new $dict, @options

Computes a minimal perfect hash table using the given dictionary,
given as hashref, arrayref or filename.

Honored options are: I<-false-positives>

It returns an object with a list of [\@G, \@V, ...].
@G contains the intermediate table of seeds needed to compute the
index of the value in @V.  @V contains the values of the dictionary.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my $options = Perfect::Hash::_handle_opts(@_);
  # $options->{'-max-time'} = 60 unless exists $options->{'-max-time'};
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
  push @{$buckets[ $class->hash($_, 0) % $size ]}, $_ for @$keys;

  # Step 2: Sort the buckets and process the ones with the most items first.
  my @sorted = sort { scalar(@{$buckets->[$b]}) <=> scalar(@{$buckets->[$a]}) } (0..$last);
  my $i = 0;
  while (@sorted) {
    my $b = $sorted[0];
    my @bucket = @{$buckets->[$b]};
    last if scalar(@bucket) <= 1; # skip the rest with 1 or 0 buckets
    shift @sorted;
    print "len[$i]=",scalar(@bucket)," [",join ",",@bucket,"]\n" if $options->{-debug};
    my int $d = 1;
    my int $item = 0;
    my %slots;

    # Repeatedly try different values of $d (the seed) until we find a hash function
    # that places all items in the bucket into free slots.
    while ($item < scalar(@bucket)) {
      my $slot = $class->hash($bucket[$item], $d) % $size;
      # epmh.py uses a list for slots here, we rather use a faster hash
      if (defined $V[$slot] or exists $slots{$slot}) {
        printf "V[$slot]=$V[$slot], slots{$slot}=$slots{$slot}, d=%d\n",$d+1 if $options->{-debug};
        $d++; $item = 0; %slots = (); # nope, try next seed
      } else {
        $slots{$slot} = $item;
        printf "slots[$slot]=$item, d=0x%x, $bucket[$item]\n", $d if $options->{-debug};
#          unless $d % 100;
        $item++;
      }
    }
    $G[$class->hash($bucket[0], 0) % $size] = $d;
    $V[$_] = $dict->{$bucket[$slots{$_}]} for keys %slots;
    print "V=[".join(",",map{defined $_ ? $_ : ""} @V),"]\n" if $options->{-debug};
    print "buckets[$i]:",scalar(@bucket)," d=$d\n" if $options->{-debug};
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
  print "len[freelist]=",scalar(@freelist)," [",join ",",@freelist,"]\n"  if $options->{-debug};

  print "xrange(",$last - $#sorted - 1,", $size)\n" if $options->{-debug};
  while (@sorted) {
    $i = $sorted[0];
    my @bucket = @{$buckets->[$i]};
    last unless scalar(@bucket);
    shift @sorted;
    my $slot = pop @freelist;
    # We subtract one to ensure it's negative even if the zeroeth slot was
    # used.
    $G[$class->hash($bucket[0], 0) % $size] = - $slot-1;
    $V[$slot] = $dict->{$bucket[0]};
  }
  print "G=[".join(",",@G),"],\nV=[".join(",",@V),"]\n" if $options->{-debug};

  if (!exists $options->{'-false-positives'}) {
    return bless [\@G, \@V, $options, $keys], $class;
  } else {
    return bless [\@G, \@V, $options], $class;
  }
}

sub option {
  return $_[0]->[2]->{$_[1]};
}

=item option $ph

Access the option hash in $ph.

=item perfecthash $ph, $key

Look up a $key in the minimal perfect hash table
and return the associated index into the initially 
given $dict.

Without C<-false-positives> it checks if the index is correct,
otherwise it will return undef.
With C<-false-positives>, the key must have existed in
the given dictionary. If not, a wrong index will be returned.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my ($G, $V) = ($ph->[0], $ph->[1]);
  my $size = scalar(@$G);
  my $h = $ph->hash($key, 0) % $size;
  my $d = $G->[$h];
  my $v = $d < 0
        ? $V->[- $d-1]
        : $d == 0
          ? $V->[$h]
          : $V->[$ph->hash($key, $d) % $size];
  if ($ph->[2]->{'-debug'}) {
    printf("ph: h0=%2d d=%3d v=%2d\t",$h,$d>0?$ph->hash($key,$d)%$size:$d,$v);
  }
  # -false-positives. no other options yet which would add a 3rd entry here,
  # so we can skip the !exists $ph->[2]->{-false-positives} check for now
  # XXX only correct if values start with 0 (the $v'd key)
  if ($ph->[3]) {
    return ($ph->[3]->[$v] eq $key) ? $v : undef;
  } else {
    return $v;
  }
}

=item false_positives

Returns 1 if the hash might return false positives,
i.e. will return the index of an existing key when
you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>, which decreases the required space from
B<3n> to B<2n>.

=cut

sub false_positives {
  return exists $_[0]->[2]->{'-false-positives'};
}

=item hash string, [seed]

pure-perl FNV-1 hash function as in http://isthe.com/chongo/tech/comp/fnv/
c variant in c_hash_impl

=cut

#BEGIN { sub DEBUG{1} }

sub hash {
  use bytes;
  my $ph = $_[0];
  #my str $str = $_[1];
  #my ($d0, $l);
  #if (DEBUG) {
  #  $d0 = $_[2];
  #  $l = scalar (split "", $str);
  #}
  my int $d = $_[2] || 0x01000193;
  for my $c (split "", $_[1]) {
    $d = ( ($d * 0x01000193) ^ ord($c) );
    #printf("%d 0x%08x\n", ord($c), $d & 0xffffffff);
  }
  #if (DEBUG) {
  #  printf("hash \"%s\":%d:%u => 0x%08x, %d\n", $str, $l, $d0, $d & 0xffffffff, $d % 11);
  #}
  return $d & 0xffffffff;
}

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

for HanovPP, Hanov and Urban.

=cut

sub save_c {
  my $ph = shift;
  require Perfect::Hash::C;
  Perfect::Hash::C->import();
  push @ISA, 'Perfect::Hash::C';
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
    my $pack = {
      8  => "c",
      16 => "s",
      32 => "l",
      64 => "q",
    };
    for my $i (0..$size-1) {
      if ($pack->{$bits}) {
        my $byte = $bits / 8;
        $G[$i] = unpack($pack->{$bits}, substr($G, $i * $byte, $byte));
      } else {
        $G[$i] = Perfect::Hash::Urban::nvecget($G, $i, $bits);
        #my $d = vec($G, $i, $bits);
        #$d = ($d - (1<<$bits)) if $d >= 1<<($bits-1);
        #$G[$i] = $d;
      }
    }
    # TODO: if @V contains only int indices
    for my $i (0..$size-1) {
      $V[$i] = Perfect::Hash::Urban::nvecget($G, $i+$size, $bits);
    }
    $G = \@G;
    $V = \@V;
  } else {
    $size = scalar(@$G);
  }
  my $gtype = s_csize($size);
  my $ugtype = $gtype eq "signed char" ? "un".$gtype : "unsigned ".$gtype;

  # TODO: which types of V. XXX also allow strings
  my $vtype = u_csize(scalar @$V);
  my $svtype = $vtype;
  $svtype =~ s/unsigned //;

  print $FH "
    $vtype h;
    $gtype d;
    $svtype v;
    /* hash indices, direct < 0, indirect > 0 */
    static const $gtype G[] = {
";
  _save_c_array(8, $FH, $G, "%3d");
  print $FH "    };";
  print $FH "
    /* values */
    static const $vtype V[] = {
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
  unless ($ph->option('-nul')) {
    print $FH "
    long l = strlen(s);";
  }
  print $FH "
    h = ($vtype)($base\_hash(0, s, l) % $size);
    d = G[h];
    v = d < 0
        ? V[($vtype)-d-1]
        : d == 0
          ? V[h]
          : V[($vtype)($base\_hash(d, s, l) % $size)];";
  if (!$ph->false_positives) { # check keys
    print $FH "
    if (memcmp(K[v],s,l)) v = -1;";
  }
  print $FH "
    return v;
}
";
  close $FH;
}

=item c_hash_impl $ph, $base

String for C code for the FNV-1 hash function, depending on C<-nul>.

=cut

sub c_hash_impl {
  my ($ph, $base) = @_;
  return "
#ifdef _MSC_VER
#define INLINE __inline
#else
#define INLINE inline
#endif

/* FNV algorithm from http://isthe.com/chongo/tech/comp/fnv/ */
static INLINE
unsigned $base\_hash(unsigned d, const unsigned char *s, const int l) {
    int i = 0;
    if (!d) d = 0x01000193; /* 16777619 */
    for (; i < l; i++) {
        d = (d * 0x01000193) ^ *s++;
    }
    return d & 0xffffffff;
}
";
}

=item c_lib c_include

empty

=cut

sub c_lib {""}

sub c_include {""}

=back

=cut

sub _test_tables {
  use utf8;
  my $n = shift || 11;
  my @dict = split /\n/, `head -n $n "examples/utf8"`;
  #$dict[19] = "éclair" if $n >= 19;
  #$dict[19] = "\x{c3}\x{a9}clair";
  my $ph = __PACKAGE__->new(\@dict, qw(-debug));
  my $keys = $ph->[3];
  # bless [\@G, \@V, \%options, $keys], $class;
  my $G = $ph->[0];
  my $V = $ph->[1];
  for (0..$#dict) {
    my $k = $keys->[$_];
    my $d = $G->[$_] < 0 ? 0 : $G->[$_];
    printf "%2d: ph=%2d   G[%2d]=%3d  V[%2d]=%3d   h(%2d,%d)=%2d %s\n",
      $_, $ph->perfecthash($k),
      $_, $G->[$_], $_, $V->[$_],
      $_, $d, hash($k,$d)%20,
      $k;
  }
}

# local testing: p -d -Ilib lib/Perfect/Hash/HanovPP.pm examples/words20
unless (caller) {
  &Perfect::Hash::_test(@ARGV)
}

1;
