package Perfect::Hash::HanovPP;
our $VERSION = '0.01';
use coretypes;
use strict;
use warnings;
our @ISA = qw(Perfect::Hash);

=head1 DESCRIPTION

Perl variant of the python "Easy Perfect Minimal Hashing" epmh.py
By Steve Hanov. Released to the public domain.
http://stevehanov.ca/blog/index.php?id=119

Based on:
Edward A. Fox, Lenwood S. Heath, Qi Fan Chen and Amjad M. Daoud, 
"Practical minimal perfect hash functions for large databases", CACM, 35(1):105-121

Also a good reference:
"Compress, Hash, and Displace" (CHD algorithm) by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
L<http://cmph.sourceforge.net/chd.html>

=head1 new Perfect::Hash::HanovPP \%dict

Computes a minimal perfect hash table using the given dictionary,
given as hashref or arrayref.  It returns an object with a list of [\@G, \@V].

@G contains the intermediate table of values needed to compute the
index of the value in @V.  @V contains the values of the dictionary.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref or arrayref
  my int $size;
  if (ref $dict eq 'ARRAY') {
    my $i = 0;
    my %dict = map {$_ => $i++} @$dict;
    $size = scalar @$dict;
    $dict = \%dict;
  } else {
    die "new $class: wrong dict argument. arrayref or hashref expected"
      if ref $dict ne 'HASH';
    $size = scalar(keys %$dict) or
      die "new $class: empty dict argument";
  }
  my $last = $size-1;

  # Step 1: Place all of the keys into buckets
  my @buckets; $#buckets = $last;
  $buckets[$_] = [] for 0 .. $last; # init with empty arrayrefs
  my $buckets = \@buckets;
  my @G; $#G = $size; @G = map {0} (0..$last);
  my @values; $#values = $last;

  # Step 1: Place all of the keys into buckets
  push @{$buckets[ hash(0, $_) % $size ]}, $_ for keys %$dict;

  # Step 2: Sort the buckets and process the ones with the most items first.
  my @sorted = sort { scalar(@{$buckets->[$b]}) <=> scalar(@{$buckets->[$a]}) } (0..$last);
  my $next = 0;
  for my $b (@sorted) {
    my @bucket = @{$buckets->[$b]};
    if (scalar(@bucket) <= 1) {
      $next = $b;
      last;
    }
    #print "len[$b]=",scalar(@bucket),"\n";

    my int $d = 1;
    my int $item = 0;
    my %slots;

    # Repeatedly try different values of $d (the seed) until we find a hash function
    # that places all items in the bucket into free slots.
    while ($item < scalar(@bucket)) {
      my $slot = hash( $d, $bucket[$item] ) % $size;
      # epmh.py uses a list for slots here, we rather use a faster hash
      if (defined $values[$slot] or exists $slots{$slot}) {
        $d++; $item = 0; %slots = (); # nope, try next seed
      } else {
        $slots{$slot} = $item;
        printf "slots[$slot]=$slot, d=%08x, item=$item: $bucket[$item]\n", $d
          unless $d % 1000;
        $item++;
      }
    }
    #print "seed=$d\n";

    $G[hash(0, $bucket[0]) % $size] = $d;
    $values[$_] = $dict->{$bucket[$_]} for values %slots;

    print "bucket[$b]=",join" ",@bucket,"\n"
      unless $b % 1000;
  }

  # Only buckets with 1 item remain. Process them more quickly by directly
  # placing them into a free slot. Use a negative value of $d to indicate
  # this.
  my @freelist;
  for my $i (0..$last) {
    push @freelist, $i unless defined $values[$i];
  }

  # use $next from the loop above: last
  print "xrange($next, $last)\n";
  for my $i ($next..$last) {
    my @bucket = @{$buckets->[$i]};
    next unless scalar(@bucket);
    my $slot = pop @freelist;
    # We subtract one to ensure it's negative even if the zeroeth slot was
    # used.
    $G[hash(0, $bucket[0]) % $size] = - $slot-1;
    $values[$slot] = $dict->{$bucket[0]};
  }

  return bless [\@G, \@values], $class;
}

=head1 perfecthash $obj, $key

Look up a $key in the minimal perfect hash table
and return the associated index into the initially 
given $dict.

=cut

sub perfecthash {
  my ($ph, $key ) = @_;
  my ($G, $V) = ($ph->[0], $ph->[1]);
  my $d = $G->[hash(0,$key) % scalar(@$G)];
  return $V->[- $d-1] if $d < 0;
  return $V->[hash($d, $key) % scalar(@$G)];
}

=head1 hash salt, string

pure-perl FNV-1 hash function as in http://isthe.com/chongo/tech/comp/fnv/

=cut

sub hash {
  my int $d = shift || 0x01000193;
  my str $str = shift;
  for my $c (split//,$str) {
    $d = ( ($d * 0x01000193) ^ ord($c) ) & 0xffffffff;
  }
  return $d
}

&_test unless caller;

# usage: perl HanovPP.pm [words...]
sub _test {
  my (@dict, %dict);
  my $dict = "/usr/share/dict/words";
  #my $dict = "words20";
  open my $d, $dict or die;
  {
    local $/;
    @dict = split /\n/, <$d>;
  }
  close $d;
  print "Reading ",scalar @dict, " words from $dict\n";
  my $ph = new __PACKAGE__, \@dict;

  unless (@ARGV) {
    if ($dict eq "examples/words20") {
      @ARGV = qw(ASL's AWOL's AZT's Aachen);
    } else {
      @ARGV = qw(hello goodbye dog cat);
    }
  }

  for my $word (@ARGV) {
    #printf "hash(0,\"%s\") = %x\n", $word, hash(0, $word);
    my $line = $ph->perfecthash( $word ) || 0;
    printf "perfecthash(\"%s\") = %d\n", $word, $line;
    printf "dict[$line] = %s\n", $dict[$line];
  }
}
