package Perfect::Hash;
use strict;
use integer;
use bytes;

our $VERSION = '0.01';
use Perfect::Hash::HanovPP (); # early load of coretypes when compiled via B::CC
use Time::HiRes qw(gettimeofday tv_interval);

use Exporter 'import';
our @EXPORT = qw(_dict_init gettimeofday tv_interval);

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

Perfect hashing is a technique for building a static hash table with no
collisions. Which means guaranteed constant O(1) access time, and for
minimal perfect hashes guaranteed minimal size. It is only possible to
build one when we know all of the keys in advance. Minimal perfect
hashing implies that the resulting table contains one entry for each
key, and no empty slots.

There exist various C and a primitive python library to generate code
to access perfect hashes and minimal versions thereof, but nothing to
use easily. C<gperf> is not very well suited to create big maps and
cannot deal with anagrams, but creates fast C code. C<Pearson> hashes
are simplier and even faster, but not guaranteed to be creatable for
small or bigger hashes.  cmph C<CHD> and the other cmph algorithms
might be the best algorithms for big hashes, but lookup time is slower
for smaller hashes.

As input we need to provide a set of unique keys, either as arrayref
or hashref.

WARNING: When querying a perfect hash you need to be sure that the key
really exists on some algorithms, as querying for non-existing keys
might return false positives.  If you are not sure how the perfect
hash deals with non-existing keys, you need to check the result
manually as in the SYNOPSIS or use the option C<-no-false-positives>
to store the values also. It's still faster than using a Bloom filter
though.

As generation algorithm there exist various hashing classes,
e.g. Hanov, CMPH::*, Bob, Pearson, Gperf.

As output there exist several dumper classes, e.g. C, XS or
you can create your own for any language e.g. Java, Ruby, ...

The best algorithm for big hashes, CHD, is derived from
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
L<http://cmph.sourceforge.net/papers/esa09.pdf>

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

=item -minimal

Selects the best available method for a minimal hash, given the
dictionary size, the options, and if the compiled algos are available.

=item -no-false-positives

Stores the values with the hash also, and checks the found key against
the value to avoid false positives. Needs much more space.

=item -optimal-size

Tries various hashes, and uses the one which will create the smallest
hash in memory. Those hashes usually will not store the value, so you
might need to check the result for a false-positive.

=item -optimal-speed

Tries various hashes, and uses the one which will use the fastest
lookup.

=item -hanovpp

Default. Big and slow. Pure perl.

=item -pearson8

Strict variant of a 8-bit (256 byte) Pearson hash table.  Generates
very fast lookup, but limited dictionaries with a 8-bit pearson table
for 5-255 keys.  Returns undef for invalid dictionaries.

=item -pearson

Non-perfect variant with adjusted pearson table size.
Try to find a n-bit sized pearson table for the given
dictionary. Keeps the best found hash table, with no guarantees that
it is a perfect hash table.
If not, collision resolution is done via static binary trees.

This version generates arbitrary sized pearson lookup tables and thus
should be able to find a perfect hash, but success is very
unlikely. The generated lookup might be however still faster than most
other hash tables for <100.000 keys.

=item -pearsonnp

"np" for non-perfect. Try to find a 8-bit (256 byte) sized pearson
table for the given dictionary. Keeps the best found hash table, with
no guarantees that it is a perfect hash table.  If not, collision
resolution is done via static binary trees.

This is also a very fast variant as the 256 byte table is guaranteed to
fit into every CPU cache.

=item -bob

Nice and easy.

=item -gperf

Pretty fast lookup, but limited dictionaries.

=item -cmph-chd

The current state of the art for bigger dictionaries.

=item -cmph-bdz

=item -cmph-brz

=item -cmph-chm

=item -cmph-fch

=item -for-c

Optimize for C libraries

=item -for-xs

Optimize for shared Perl XS code. Stores the values as perl types.

=item -hash=C<name>

Use the specified hash function instead of the default.
Only useful for hardware assisted C<crc32> and C<aes> system calls,
provided by compiler intrinsics (sse4.2) or libz.
See -hash=help for a list of all supported hash function names:
C<crc32>, C<aes>, C<crc32-libz>

The hardware assisted C<crc32> and C<aes> functions add a run-time
probe with slow software fallback code.  C<crc32-libz> does all this
also, and is especially optimized for long keys to hash them in
parallel.

=item -pic

Optimize the generated table for inclusion in shared libraries via a
constant stringpool. This reduces the startup time of programs using a
shared library containing the generated code. As with L<gperf>
C<--pic>

=item -nul

Allow C<NUL> bytes in keys, i.e. store the length for keys and compare
binary via C<strncmp>.

=item -null-strings

Use C<NULL> strings instead of empty strings for empty keyword table
entries. This reduces the startup time of programs using a shared
library containing the generated code (but not as much as the
declaration C<-pic> option), at the expense of one more
test-and-branch instruction at run time.

=item -7bit

Guarantee that all keys consist only of 7-bit ASCII characters, bytes
in the range 0..127.

=item -ignore-case

Consider upper and lower case ASCII characters as equivalent. The
string comparison will use a case insignificant character
comparison. Note that locale dependent case mappings are ignored.

=item -unicode-ignore-case

Consider upper and lower case unicode characters as equivalent. The
string comparison will use a case insignificant character
comparison. Note that locale dependent case mappings are done via
C<libicu>.

=back

=cut

#our @algos = qw(HanovPP Urban Pearson8 Pearson PearsonNP 
#                Bob Gperf CMPH::CHD CMPH::BDZ CMPH::BRZ CMPH::CHM CMPH::FCH);
our @algos = qw(HanovPP Urban Pearson8 Pearson PearsonNP);
our %algo_todo = map {$_=>1} qw(-pearson8 -pearson -pearsonnp);
our %algo_methods = map {
  my ($m, $o) = ($_, $_);
  $o =~ s/::/-/g;
  lc $o => "Perfect::Hash::$m"
} @algos;

# split hash or filename with keys
# into 2 arrays of keys and values
sub _dict_init {
  my $dict = shift;
  if (ref $dict eq 'ARRAY') {
    return ($dict, []);
  }
  elsif (ref $dict ne 'HASH') {
    if (!ref $dict and -e $dict) {
      my @keys;
      open my $d, "<", $dict or die; {
        local $/;
        @keys = split /\n/, <$d>;
        #TODO: check for key<ws>value or just lineno
      }
      close $d;
      return (\@keys, []);
    } else {
      die "wrong dict argument. arrayref, hashref or filename expected";
    }
  }
  # HASHREF:
  my $size = scalar(keys %$dict) or
    die "new: empty dict argument";
  my @keys = ();
  $#keys = $size - 1;
  my @values = ();
  $#values = $size - 1;
  my $i = 0;
  for (sort keys %$dict) {
    $keys[$i] = $_;
    $values[$i] = $dict->{$_};
    $i++;
  }
  return (\@keys, \@values);
}

sub new {
  my $class = shift;
  my $dict = shift;
  my $option = shift || '-hanovpp'; # the first must be the algo method
  my $method = $algo_methods{substr($option,1)};
  if (substr($option,0,1) eq "-" and $method) {
    eval "require $method;";
  } else {
    # no algo given, check which would be the best
    unshift @_, $option;
    # TODO: choose the right default, based on the given options and the dict size,
    # and if we have the compiled methods or only pure-perl available.
    $method = "Perfect::Hash::HanovPP"; # for now only pure-perl
    #eval "require $method;";
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

See L<Perfect::Hash::XS/save_xs>

=cut

sub save_c {
  require Perfect::Hash::C;
  Perfect::Hash::C->save_c(@_);
}

sub save_xs {
  require Perfect::Hash::XS;
  Perfect::Hash::XS->save_xs(@_);
}

=back

=head1 SEE ALSO

Algorithms:

L<Perfect::Hash::HanovPP>,
L<Perfect::Hash::Pearson>,
L<Perfect::Hash::Pearson8>,
L<Perfect::Hash::PearsonNP>,
L<Perfect::Hash::Urban>,
L<Perfect::Hash::Bob>,
L<Perfect::Hash::CMPH::CHD>,
L<Perfect::Hash::CMPH::BDZ>,
L<Perfect::Hash::CMPH::BRZ>,
L<Perfect::Hash::CMPH::CHM>,
L<Perfect::Hash::CMPH::FCH>

Output classes:

L<Perfect::Hash::C>,
L<Perfect::Hash::XS>

=cut

&_test(@ARGV) unless caller;

# usage: perl -Ilib lib/Perfect/Hash.pm
sub _test {
  my (@dict, %dict);
  my $dict = shift || "/usr/share/dict/words";
  my $method = shift || "";
  #my $dict = "examples/words20";
  unless (-f $dict) {
    unshift @_, $dict;
    $dict = "/usr/share/dict/words";
  }
  open my $d, "<", $dict or die; {
    local $/;
    @dict = split /\n/, <$d>;
  }
  close $d;
  print "Reading ",scalar @dict, " words from $dict\n";
  my $t0 = [gettimeofday];
  my @options = grep /^-/, @_;
  @_ = grep !/^-/, @_;
  my $ph = new __PACKAGE__, \@dict, $method, @options;
  return unless $ph;
  print "generated $method ph in ",tv_interval($t0),"s\n";

  unless (@_) {
    # pick some random values
    push @_, $dict[ int(rand(scalar @dict)) ] for 0..4;
  }

  for my $word (@_) {
    #printf "hash(0,\"%s\") = %x\n", $word, hash(0, $word);
    my $line = $ph->perfecthash( $word ) || 0;
    printf "perfecthash(\"%s\") = %d\t", $word, $line;
    printf "dict[$line] = %s\n", $dict[$line];
    if ($dict[$line] eq $word) {
      print "$word at index $line\n";
    } else {
      print "$word not found\n";
    }
  }
}

1;
