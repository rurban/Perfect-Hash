package Perfect::Hash::HanovPP;
our $VERSION = '0.01';
use coretypes;
use strict;
use warnings;

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

=head1 new Perfect::Hash::HanovPP \@dict

Computes a minimal perfect hash table using the given dictionary,
given as arrayref.  It returns an object with a list of [\@G, \@V].

@G contains the intermediate table of values needed to compute the
index of the value in @V.  @V contains the values of the dictionary.

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #arrayref
  my int $size = scalar @$dict or
    die "new $class: empty dict argument. arrayref expected";
  my $last = $size-1;

  # Step 1: Place all of the keys into buckets
  my @buckets; $#buckets = $last;
  $buckets[$_] = [] for 0 .. $last; # init with empty arrayrefs
  my $buckets = \@buckets;
  my @G; $#G = $size; @G = map {0} (0..$last);
  my @values; $#values = $last;

  # Step 1: Place all of the keys into buckets
  for my $key (@$dict) {
    push $buckets[ hash(0, $key) % $size ], $key;
  }
  for (0 .. scalar(@$buckets)-1) {
    # init rest with empty array
    $buckets->[$_] = [] unless defined $buckets->[$_];
  }
  # Step 2: Sort the buckets and process the ones with the most items first.
  my @sorted;
  @sorted = sort { scalar(@{$buckets->[$b]}) <=> scalar(@{$buckets->[$a]}) } (0..$last);
  for my $i (@sorted) {
    my $bucket = $buckets->[$i];
    next if scalar(@$bucket) <= 1;
    #print "len[$i]=",scalar(@$bucket),"\n";

    my int $d = 1;
    my int $item = 0;
    my %slots;

    # Repeatedly try different values of d until we find a hash function
    # that places all items in the bucket into free slots
    while ($item < scalar(@$bucket)) {
      my $slot = hash( $d, $bucket->[$item] ) % $size;
      #epmh.py uses a list for slots here, we rather use a faster hash
      if (defined $values[$slot] or exists $slots{$slot}) {
        $d++; $item = 0; %slots = (); # nope, try next seed
      } else {
        $slots{$slot} = $slot;
        printf "slots[$slot]=$slot, d=%08x, item=$item: $bucket->[$item]\n", $d
          unless $i % 1000;
        $item++;
      }
    }
    #print "seed=$d\n";

    $G[hash(0, $bucket->[0]) % $size] = $d;
    for my $j (0 .. scalar(@$bucket)-1) {
      if (exists $slots{$j}) {
        $values[$slots{$j}] = $dict->[$bucket->[$j]];
        print "values[$slots{$j}]=$dict->[$bucket->[$j]]\n";
      }
    }
    print "bucket[$i]=",join" ",@{$bucket},"\n"
      unless $i % 1000;
  }

  # Only buckets with 1 item remain. Process them more quickly by directly
  # placing them into a free slot. Use a negative value of d to indicate
  # this.
  my @freelist;
  for my $i (0..$last) {
    push @freelist, $i unless defined $values[$i];
  }

=pod

  TODO: NOT YET FINISHED and TESTED

  for b in xrange( b, size ):
      bucket = buckets[b]
      if len(bucket) == 0: break
      slot = freelist.pop()
      # We subtract one to ensure it's negative even if the zeroeth slot was
      # used.
      G[hash(0, bucket[0]) % size] = -slot-1 
      values[slot] = dict[bucket[0]]

=cut

    return bless [\@G, \@values)], $class;
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

# test code

my @dict;
my $dict = "/usr/share/dict/words";
open my $d, $dict or die;
{
  local $/;
  @dict = split /\n/, <$d>;
}
close $d;
print "Reading ",scalar @dict, " words from $dict\n";
my $ph = new Perfect::Hash::Hanov(\@dict);

@ARGV = qw(hello goodbye dog cat) unless @ARGV;

for my $word (@ARGV) {
  printf "hash(0,\"%s\") = %x\n", $word, hash(0, $word);
  my $line = $ph->perfecthash( $word ) || 0;
  printf "perfecthash(\"%s\") = %x\n", $word, $line;
  printf "dict[$line] = %s\n", $dict[$line];
}
