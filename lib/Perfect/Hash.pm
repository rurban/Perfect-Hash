package Perfect::Hash;
our $VERSION = '0.01';

=head1 NAME

Perfect::Hash - generate perfect hashes

=head1 SYNOPSIS

    use Perfect::Hash;
    my @dict = split/\n/,`cat /usr/share.dict/words`;

    my $ph = Perfect::Hash->new(\@dict, -minimal);
    for (@ARGV) {
      my $v = $ph->perfecthash($_);
      if ($dict[$v] eq $_) {
        print "$_ at line $v";
      } else {
        print "$_ not found";
      }
    }

=head1 DESCRIPTION

Perfect hashing is a technique for building a hash table with no
collisions. Which means guaranteed constant O(1) access time, and for
minimal perfect hashes guaranteed minimal size. It is only possible to
build one when we know all of the keys in advance. Minimal perfect
hashing implies that the resulting table contains one entry for each
key, and no empty slots.

There exist various C and a primitive python library to generate code
to access perfect hashes and minimal versions thereof, but nothing to
use easily. gperf is not very well suited to create big maps and
cannot deal with anagrams, but creates fast C code. pearson hashes are
also pretty fast, but not guaranteed to be creatable for small hashes.
cmph CHD and the other cmph algorithms might be the best algorithms
for big hashes, but lookup time is slower for smaller hashes.

The best algorithm for big hashes, CHD, is derived from
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
L<http://cmph.sourceforge.net/papers/esa09.pdf>

As input we need to provide a set of unique keys, either as arrayref
or hashref.

WARNING: When querying a perfect hash you need to be sure that key
really exists on some algorithms, as non-existing keys might return
false positives.  If you are not sure how the perfect hash deals with
non-existing keys, you need to check the result manually as in the
SYNOPSIS.  It's still faster than using a Bloom filter though.

As generation algorithm there exist various hashing classes,
e.g. Hanov, CMPH::*, Bob, Pearson, Gperf.

As output there exist several dumper classes, e.g. C, XS or
you can create your own for any language e.g. Java, Ruby, ...

=head1 METHODS

=over

=item new hashref|arrayref, algo, options...

Evaluate the best algorithm given the dict size and output options and 
generate the minimal perfect hash for the given keys. 

The values in the dict are not needed to generate the perfect hash function,
but might be needed later. So you can use either an arrayref where the index
is returned, or a full hashref.

Options for output classes are prefixed with C<-for->,
e.g. C<-for-c>. They might be needed to make a better decision which
perfect hash to use.

The following algorithms and options are planned:

=over 4

=item -hanovpp (default, pure perl)

=item -optimal-size

tries various hashes, and uses the one which will create the smallest
hash in memory. Those hashes usually will not store the value, so you
need to check the result for a false-positive.

=item -optimal-speed

tries various hashes, and uses the one which will use the fastest
lookup.

=item -minimal

Selects the best available method for a minimal hash, given the
dictionary size, the options, and if the compiled algos are available.

=item -bob

=item -gperf

=item -pearson

=item -cmph-chd

=item -cmph-bdz

=item -cmph-brz

=item -cmph-chm

=item -cmph-fch

=item -for-c

=item -for-xs

=item -for-sharedlib

=back

=cut

our @algos = qw(HanovPP Bob Pearson Gperf CMPH::CHD CMPH::BDZ CMPH::BRZ CMPH::CHM CMPH::FCH);
our %algo_methods = map {
  my $m = $_ =~ s/::/-/;
  lc $m => "Perfect::Hash::" . $_
} @algos;

sub new {
  my $class = shift;
  my $dict = shift;
  my $option = shift || '-hanov'; # the first must be the algo method
  my $method = $algo_methods{substr($option,2)};
  if (substr($option,1,1) eq "-" and $method) {
    ;
  } else {
    # choose the right default, based on the given options and the dict size
    $method = "Perfect::Hash::HanovPP"; # for now only pure-perl
    require Perfect::Hash::HanovPP;
  }
  return $method->new($dict, @_);
}

=item perfecthash $key

Returns the index into the arrayref, resp. the provided hash value.

=cut

sub perfecthash {
  my $ph = shift;
  die 'Need a delegated Perfect::Hash sub class' if ref $ph eq 'Perfect::Hash';
  return $ph->perfecthash(@_);
}

=item false_positives

Returns 1 if perfecthash might return false positives. I.e. You'll need to check
the result manually again.

=item save_c fileprefix, options

See L<Perfect::Hash::C/save_c>

=item save_xs file, options

See L<Perfect::Hash::xs/save_xs>

=cut

sub save_c {
  require Perfect::Hash::C;
  my $obj = bless shift, "Perfect::Hash::C";
  $obj->save_c(@_);
}

sub save_xs {
  require Perfect::Hash::XS;
  my $obj = bless shift, "Perfect::Hash::XS";
  $obj->save_xs(@_);
}

=back

=head1 SEE ALSO

Algorithms:

  - L<Perfect::Hash::HanovPP>
  - L<Perfect::Hash::Bob>
  - L<Perfect::Hash::Pearson>
  - L<Perfect::Hash::CMPH::CHD>
  - L<Perfect::Hash::CMPH::BDZ>
  - L<Perfect::Hash::CMPH::BRZ>
  - L<Perfect::Hash::CMPH::CHM>
  - L<Perfect::Hash::CMPH::FCH>

Output classes:

  - L<Perfect::Hash::C>
  - L<Perfect::Hash::XS>

=cut


&_test(@ARGV) unless caller;

# usage: perl -Ilib lib/Perfect/Hash.pm
sub _test {
  my (@dict, %dict);
  my $dict = shift || "/usr/share/dict/words";
  #my $dict = "examples/words20";
  unless (-f $dict) {
    unshift @_, $dict;
    $dict = "/usr/share/dict/words";
  }
  open my $d, $dict or die; {
    local $/;
    @dict = split /\n/, <$d>;
  }
  close $d;
  print "Reading ",scalar @dict, " words from $dict\n";
  my $ph = new __PACKAGE__, \@dict;

  unless (@_) {
    # TODO: pick random values, about 50%
    if ($dict eq "examples/words20") {
      @_ = qw(ASL's AWOL's AZT's Aachen);
    } else {
      @_ = qw(hello goodbye dog cat);
    }
  }

  for my $word (@_) {
    #printf "hash(0,\"%s\") = %x\n", $word, hash(0, $word);
    my $line = $ph->perfecthash( $word ) || 0;
    printf "perfecthash(\"%s\") = %d\n", $word, $line;
    printf "dict[$line] = %s\n", $dict[$line];
    if ($dict[$line] eq $word) {
      print "$word at index $line\n";
    } else {
      print "$word not found\n";
    }
  }
}
