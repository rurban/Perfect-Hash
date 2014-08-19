package Perfect::Hash;
use strict;
use integer;
use bytes;

our $VERSION = '0.01';
use Perfect::Hash::HanovPP (); # early load of coretypes when compiled via B::CC
use Time::HiRes qw(gettimeofday tv_interval);

use Exporter 'import';
our @EXPORT = qw(_dict_init gettimeofday tv_interval);

# Not yet:      Bob
#               CMPH::BMZ8 CMPH::BRZ Cuckoo RobinHood HAMT
our @algos = qw(HanovPP Hanov Urban Pearson8 Pearson PearsonNP
                CMPH::BDZ_PH CMPH::BDZ CMPH::BMZ CMPH::CHM
                CMPH::FCH CMPH::CHD_PH CMPH::CHD
                Switch Gperf);
# Still failing:
our %algo_todo = map {$_=>1} # pure-perl and save_c
  qw(-gperf -cmph-bdz_ph -cmph-bdz -cmph-bmz -cmph-chm -cmph-fch -cmph-chd_ph
     -cmph-chd -cmph-bmz8 -cmph-brz);

=head1 NAME

Perfect::Hash - generate perfect hashes, library backend for phash

=head1 SYNOPSIS

    # generate c file for readonly lookup
    phash keyfile --prefix=phash ...

    # pure-perl usage
    use Perfect::Hash;
    my @dict = split/\n/,`cat /usr/share/dict/words`;
    my $ph = Perfect::Hash->new(\@dict, -minimal);
    for (@ARGV) {
      my $v = $ph->perfecthash($_);
      print ($dict[$v] eq $_ ? "$_ at line ".$v+1."\n" : "$_ not found\n");
    }

    Perfect::Hash->new("keyfile", '-urban', ...)->save_c;
    # or just:
    phash keyfile --urban
    cc -O3 -msse4.2 phash.c ... -lz

    phash /usr/share/dict/words --cmph-bdz_ph --nul
    cc -O3 phash.c ... -lcmph

=head1 DESCRIPTION

Perfect hashing is a technique for building a static hash table with no
collisions. Which means guaranteed constant O(1) access time, and for minimal
perfect hashes even guaranteed minimal size. It is only possible to build one
when we know all of the keys in advance. Minimal perfect hashing implies that
the resulting table contains one entry for each key, and no empty slots.

As input we need to provide a set of unique keys, either as arrayref or
hashref or as keyfile. The keys can so far only be strings (will be extended
to ints on demand) and the values can so far be only ints and strings.  More
types later.

As generation algorithm there exist various hashing and other fast lookup methods:
Hanov, HanovPP, Urban, CMPH::*, Bob, Pearson, Gperf, Cuckoo, Switch, ...
Not all generated lookup methods are perfect hashes per se. We also implemented
traditional methods which might be faster for smaller key sets, like nested switches,
hash array mapped tries or ordinary linear addressing hash tables.

As output there exist several output formater classes, e.g. C and later: XS,
Java, Ruby, PHP, Python, PECL.  For Lua or Lisp this is probably not needed as
they either roll their own, or FFI into the generated C library.  For Go,
Rust, Scala, Clojure, etc just roll you own library, based on an existing one.

The best algorithm used in Hanov and various others is derived from
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
L<http://cmph.sourceforge.net/papers/esa09.pdf>

There exist various C and a simple python script to generate code to
access perfect hashes and minimal versions thereof, but nothing to use
easily. C<gperf> is not very well suited to create big maps and cannot deal
with certain anagrams, but creates fast C code for small dictionaries.
C<Pearson> hashes are simplier and fast for small machines, but not guaranteed
to be creatable for small or bigger hashes.  cmph C<CHD>, C<BDZ_PH> and the
other cmph algorithms might be the best algorithms for big hashes, but lookup
time is slower for smaller hashes and you need to link to an external library.

=head1 METHODS

=over

=item new hashref|arrayref|keyfile, algo, options...

Evaluate the best algorithm given the dict size and output options and
generate the minimal perfect hash for the given keys.

The values in the dict are not needed to generate the perfect hash function,
but might be needed later. So you can use either an arrayref where the index
is returned, or a full hashref or a keyfile as with C<gperf>.

Options for output classes are prefixed with C<-for->,
e.g. C<-for-c>. They might be needed to make a better decision which
perfect hash to use.

The following algorithms and options are done and planned:

=over 4

=item -false-positives

Do not store the keys of the hash. Needs much less space and is faster, but
might only be used either if you know in advance that you'll never lookup not
existing keys, or check the result manually by yourself to avoid false
positives.

=item -minimal (not yet)

Selects the best available method for a minimal hash, given the
dictionary size, the options, and if the compiled algos are available.

=item -optimal-size (not yet)

Tries various hashes, and uses the one which will create the smallest
hash in memory. Those hashes usually will not store the value, so you
might need to check the result for a false-positive.

=item -optimal-speed (not yet)

Tries various hashes, and uses the one which will use the fastest
lookup.

=item -hanovpp

The default pure perl method.

=item -hanov

Improved version of HanovPP, using optimized XS methods,
2-3x faster with HW supported iSCSI CRC32 (via zlib or manually).

The fast hash function requires a relatively new 64bit Intel, AMD or ARM
processor.  This might need the external zlib library (-lz) at run-time.

=item -urban

Improved version of Hanov, using compressed temp. arrays and
the same optimized XS methods and hash functionsas in -hanov.
But can only store index values in a limited range, not strings.

=item -pearson8

Strict variant of a 8-bit (256 byte) Pearson hash table.  Generates fast
lookups for small 8-bit machines, but limited dictionaries with a 8-bit
pearson table for 5-255 keys.  Returns undef for invalid dictionaries.

=item -pearson

Non-perfect variant with adjusted pearson table size.
Try to find a n-bit sized pearson table for the given
dictionary. Keeps the best found hash table, with no guarantees that
it is a perfect hash table.
If not, collision resolution is done via static binary trees.

This version generates arbitrary sized pearson lookup tables and thus
should be able to find a perfect hash, but success is very
unlikely.

=item -pearsonnp

"np" for non-perfect. Try to find a 8-bit (256 byte) sized pearson table for
the given dictionary. Keeps the best found hash table, with no guarantees that
it is a perfect hash table.  If not, collision resolution is done via static
binary search. I<(currently only linear search)>.

This is also a very fast variant for small 8-bit machines as the 256 byte
table is guaranteed to fit into every CPU cache, but it only iterates
in byte steps.

=item -bob (not yet)

Generates nice and easy C code without external library dependency.
However to generate -bob you need a C compiler.

=item -gperf

Generates pretty fast lookup, because it is not hashing the string,
it just takes some characters from the string to create a unique key.
Only limited dictionaries and smaller sizes.

Currently only via the C<gperf> executable. Planned to do it in pure-perl
to be independent and improve the generated memcpy comparisons, as in C<-switch>.

=item -switch

Only for smaller dictionaries.
Uses no hash function nor hash table, just generates a fast switch
table in C<C> as with C<gperf --switch> for smaller dictionaries.

Generates a nested switch table, first switching on the size and then on the
best combination of keys. The difference to C<gperf --switch> is the automatic
generation of nested switch levels, depending on the number of collisions, and
it is optimized to use word size comparisons for the fixed length
comparisons, which is up to 50% faster than C<memcmp>.
The performance is comparable to the best perfect hashes.

=item -cmph-bdz_ph

The C<-cmph-*> methods are the current state of the art for bigger
dictionaries.  This needs the external C<cmph> library even at run-time.

The performance depends on the dictionary size.
-cmph-bdz_ph is usually the fastest cmph method for
1.000 - 250.000 keys, and -cmph-chm is usually the second best option.

=item -cmph-bdz

=item -cmph-bmz

=item -cmph-chm

=item -cmph-fch

=item -cmph-chd_ph

=item -cmph-chd

=item -for-c (default)

Optimize for C libraries

=item -for-xs (not yet)

Optimize for shared Perl XS code. Stores the values as perl types.

=item -for-I<class> (not yet)

Optimize for any I<CLASS> output formatter class, loaded dynamically.
Such as PYTHON, RUBY, JAVA, PHP, PECL, ...

=item -hash=C<name> (not yet)

Use the specified hash function instead of the default.
Only useful for hardware assisted C<crc32> and C<aes> system calls,
provided by compiler intrinsics (sse4.2) or libz. Note that some
zlib libraries do not provide a HW-assisted fast crc32 function,
rather a slow SW variant.
See -hash=help for a list of all supported hash function names:
C<crc32_zlib>, C<fnv>, C<crc32_sse42>, C<aes>, ...

The hardware assisted C<crc32> and C<aes> functions add a run-time probe with
slow software fallback code (not yet). C<crc32_zlib> does all this also, and
is especially optimized for long keys to hash them in parallel, if implemented
in your library.

=item -pic (not yet)

Optimize the generated table for inclusion in shared libraries via a
constant stringpool. This reduces the startup time of programs using a
shared library containing the generated code. As with L<gperf>
C<--pic>

gperf:

-P/--pic does a perfect optimization but may require some small code changes
(see the gperf documentation for details), whereas --null-strings does only a
half-hearted optimization but works without needing any change to surrounding
code.

=item -nul

Allow C<NUL> bytes in keys, i.e. store the length for keys and compare
binary via C<memcmp>, not C<strcmp>.

=item -null-strings (not yet)

Use C<NULL> strings instead of empty strings for empty keyword table
entries without C<-false-positives>. This reduces the startup time of
programs using a shared library containing the generated code (but not
as much as the declaration C<-pic> option), at the expense of one more
test-and-branch instruction at run time.

=item -7bit (not yet)

Guarantee that all keys consist only of 7-bit ASCII characters, bytes
in the range 0..127.

=item -ignore-case (not yet)

Consider upper and lower case ASCII characters as equivalent. The
string comparison will use a case insignificant character
comparison. Note that locale dependent case mappings are ignored.

=item -unicode-ignore-case (not yet)

Consider upper and lower case unicode characters as equivalent. The
string comparison will use a case insignificant character
comparison. Note that locale dependent case mappings are planned to be done via
C<libicu> or the better C<libunistring>.

=back

=cut

our %algo_methods = map {
  my ($m, $o) = ($_, $_);
  $o =~ s/::/-/g;
  lc $o => "Perfect::Hash::$m"
} @algos;

# split hash or filename with keys
# into 2 arrays of keys and values
# avoid power of 2 sizes, for less modulo hassle
# if so just add a dummy "" key at the end
sub _dict_init {
  my $dict = shift;
  if (ref $dict eq 'ARRAY') {
    if (sprintf("%b", scalar @$dict) =~ /000+$/) {
      push @$dict, "";
    }
    return ($dict, []);
  }
  elsif (ref $dict ne 'HASH') {
    if (!ref $dict and -e $dict) {
      my @keys;
      open my $d, "<", $dict or die; {
        local $/;
        @keys = split /\n/, <$d>;
        #TODO: check for key<ws>value or just lineno
        push @keys, "" if sprintf("%b", scalar @keys) =~ /000+$/;
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
  if (sprintf("%b", $size) =~ /000+$/) {
    push @keys, "";
    push @values, -1;
  }
  return (\@keys, \@values);
}

sub new {
  my $class = shift;
  my $dict = shift;
  my $option = shift; # the first must be the algo method
  my $method = $algo_methods{substr($option,1)} if $option;
  if (substr($option,0,1) eq "-" and $method) {
  } else {
    # no or wrong algo method given, check which would be the best
    unshift @_, $option;
    $method = analyze_data($dict, @_);
    print "Using $method\n";
  }
  eval "require $method;" unless $method eq 'Perfect::Hash::HanovPP';
  return $method->new($dict, @_);
}

=item analyze_data $dict, @options

Scans the given dictionary, honors the given options and current architecture
and returns the name of the recommended hash table algorithm for fast lookups.

=cut

sub analyze_data {
  my $dict = shift;
  my @options = @_;
  # TODO: choose the right default, based on the given options and the
  # dict size and types, architecture,
  # and if we have the compiled methods, fast iSCSI CRC32 or only
  # pure-perl available.
  my $method = "Perfect::Hash::HanovPP"; # for now only pure-perl
  return $method;
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

Returns 1 if perfecthash might return false positives.  I.e. will return the
index of an existing key when you searched for a non-existing key. Then you'll
need to check the result manually again.

The default is undef, unless you created the hash with the option
C<-false-positives>.

=cut

sub false_positives {
  return $_[0]->option('-false-positives');
}


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

=item hash_murmur3 string, [seed]

pure-perl murmur3 int32 finalizer

=cut

sub hash_murmur3 {
  use bytes;
  my $ph = shift;
  my str $str = shift;
  my int $h = shift || 0;
  for my $c (split "", $str) {
    $h = $h ^ ord($c); # XXX better slice strings into 4 bytes
    $h ^= $h >> 16;
    $h *= 0x85ebca6b;
    $h ^= $h >> 13;
    $h *= 0xc2b2ae35;
    $h ^= $h >> 16;
  }
  return $h
}

=back

=head1 SEE ALSO

F<script/phash> for the frontend.

=head2 Algorithms

L<Perfect::Hash::HanovPP>,
L<Perfect::Hash::Hanov>,
L<Perfect::Hash::Urban>,
L<Perfect::Hash::Pearson>,
L<Perfect::Hash::Pearson8>,
L<Perfect::Hash::PearsonNP>,
L<Perfect::Hash::Bob> I<(not yet)>,
L<Perfect::Hash::Gperf> I<(not yet)>,
L<Perfect::Hash::CMPH::CHM>,
L<Perfect::Hash::CMPH::BMZ>,
L<Perfect::Hash::CMPH::BMZ8> I<(not yet)>,
L<Perfect::Hash::CMPH::BRZ> I<(not yet)>,
L<Perfect::Hash::CMPH::FCH>
L<Perfect::Hash::CMPH::BDZ>,
L<Perfect::Hash::CMPH::BDZ_PH>,
L<Perfect::Hash::CMPH::CHD>,
L<Perfect::Hash::CMPH::CHD_PH>

=head2 Output classes

Output classes are loaded dynamically from a C<-for-class> option,
the option must be lowercase, the classsname must be uppercase.

L<Perfect::Hash::C> C<-for-c> (C library)

L<Perfect::Hash::XS> C<-for-xs> (compiled perl extension)

Planned:

L<Perfect::Hash::PYTHON> C<-for-python> (compiled python extension)

L<Perfect::Hash::RUBY> C<-for-ruby> (compiled ruby extension)

L<Perfect::Hash::JAVA> C<-for-java>

L<Perfect::Hash::PHP> C<-for-php> (pure php)

L<Perfect::Hash::PECL> C<-for-pecl> (compiled php extension)

For Lua or Lisp this is probably not needed as they either roll their own,
or FFI into the generated C library.
For Go, Rust, Scala, Clojure, etc just roll you own library, based on an
existing one.

=head1 TEST REPORTS

CPAN Testers: L<http://cpantesters.org/distro/P/Perfect-Hash>

Travis: L<https://travis-ci.org/rurban/Perfect-Hash.png|https://travis-ci.org/rurban/Perfect-Hash/>

Coveralls: L<https://coveralls.io/repos/rurban/Perfect-Hash/badge.png|https://coveralls.io/r/rurban/Perfect-Hash?branch=master>

=head1 BENCHMARKS

linux/amd64 with a dictionary size=99171, lookup every key.
with Intel Core i5-2300 CPU @ 2.80GHz with native iSCSI CRC32-C from zlib.

    size=99171  (smaller sec and size is better)
    Method       *lookup*  generate compile   c size   exesize  options
    hanovpp      0.008362  1.477029 1.500102  1199097  2434100  -false-positives -nul
    hanov        0.008446  0.868262 1.419405  1197842  2434154  -false-positives -nul
    urban        0.008572  0.974272 1.493917  1197842  2434154  -false-positives -nul
    pearson      0.019542 61.215180 5.074468  8523515  8744176  -false-positives -nul
    pearsonnp    0.083651 10.993980 2.401196  2647938  4551377  -false-positives -nul
    switch       0.307571  0.108520 106.246898 7180505 4903978  -false-positives -nul
    gperf                  0.147118 60.459954       0        0  -false-positives -nul
    			with -1 errors. (killed)
    ----
    hanovpp      0.011389  1.842678 2.353696  2393751  3227319  -nul
    hanov        0.012029  1.113523 2.432361  2392496  3227389  -nul
    urban        0.012638  1.181999 2.499644  2392496  3227389  -nul
    pearson      0.019283 60.902602 5.737236  9707677  9530106  -nul
    pearsonnp    0.086610 10.706328 3.068488  3842596  5346448  -nul
    cmph-bdz_ph  0.028641  0.214257 0.852713    67005  1664617  -nul
    cmph-bdz     0.036652  0.235935 0.818024    98105  1674529  -nul
    cmph-bmz     0.028345  0.303834 1.019334  1590581  2096417  -nul
    cmph-chm     0.026548  0.267057 1.070887  3074292  2469305  -nul
    cmph-fch     0.025842 12.207561 0.851390   196141  1698857  -nul
    cmph-chd_ph  0.027425  0.213768 0.829349    36049  1652489  -nul
    cmph-chd     0.037807  0.223218 0.847786   141652  1692769  -nul
    switch       0.311235  0.122087 106.789416 7180505 4903978  -nul
    gperf                  0.157462 62.742600       0        0  -nul
    			with -1 errors. (killed)
    ----
    hanovpp      0.006855  1.421162 1.354903  1199134  2434100  -false-positives
    hanov        0.008220  0.825426 1.319486  1197879  2434154  -false-positives
    urban        0.008200  0.920019 1.406430  1197879  2434154  -false-positives
    pearson      0.020852 60.960436 4.893361  8525108  8745478  -false-positives
    pearsonnp    0.085384 10.585342 2.363646  2647985  4551553  -false-positives
    switch       0.306727  0.105216 106.818486 7180523 4885802  -false-positives
    gperf                  0.144518 65.111405       0        0  -false-positives
			with -1 errors. (killed)
    ----
    hanovpp      0.009979  1.680235 2.185542  2393768  3227327
    hanov        0.011189  1.015519 2.202126  2392513  3227381
    urban        0.010470  1.086080 2.247296  2392513  3227381
    pearson      0.021110 60.802902 5.671212  9717351  9535291
    pearsonnp    0.082384 10.706795 3.050614  3842623  5343536
    cmph-bdz_ph  0.017310  0.217699 0.850289    67006  1664617
    cmph-bdz     0.023326  0.222797 0.845723    98106  1674529
    cmph-bmz     0.025361  0.323237 0.939358  1590582  2096417
    cmph-chm     0.026992  0.269317 1.073590  3074290  2469305
    cmph-fch     0.026069 12.418100 0.844249   196142  1698857
    cmph-chd_ph  0.027299  0.219664 0.833660    36050  1652489
    cmph-chd     0.039164  0.219995 0.835140   141653  1692769
    switch       0.308609  0.117142 106.622500 7180523 4885802
    gperf                  0.150903 69.595114       0        0
			with -1 errors. (killed)
    ----

Medium sized dictionary with 2000 keys:
C<perl -Mblib examples/bench.pl -size 2000 -nul>

    Method       *lookup*  generate compile   c size   exesize  options
    hanovpp      0.001288  0.024404 0.110621    43698    65615  -nul
    hanov        0.001331  0.012790 0.113180    43404    65685  -nul
    urban        0.001356  0.014805 0.112848    43404    65685  -nul
    pearson      0.001332  15.567089 0.161991   180558   180741  -nul
    pearsonnp    0.001373  0.201908 0.135624   102930   143248  -nul
    cmph-bdz_ph  0.001562  0.003156 0.083367     1563    42057  -nul
    cmph-bdz     0.001642  0.003619 0.084053     2261    42057  -nul
    cmph-bmz     0.001657  0.005309 0.086036    34671    50377  -nul
    cmph-chm     0.001698  0.002993 0.087662    64383    58441  -nul
    cmph-fch     0.001740  0.088907 0.083519     6673    42929  -nul
    cmph-chd_ph  0.001802  0.002350 0.083385     1102    42057  -nul
    cmph-chd     0.001937  0.002489 0.087175     3390    42297  -nul
    switch       0.001256  0.002336 1.582009   151038   106730  -nul
    gperf        0.001344  0.003922 0.849867   295195   297154  -nul

Small dictionary with 127 keys:

    Method       *lookup*  generate compile   c size   exesize  options
    hanovpp      0.001247  0.001904 0.069912     3454    11575
    hanov        0.001231  0.000946 0.070709     3200    11629
    urban        0.001298  0.001020 0.072471     3200    11629
    pearson      0.001178  0.068758 0.072311    12354    19240
    pearsonnp    0.001253  0.018204 0.072419    12386    19259
    cmph-bdz_ph  0.001271  0.000412 0.066264      335    10009
    cmph-bdz     0.001317  0.000403 0.066471      424    10033
    cmph-bmz     0.001277  0.000539 0.066814     2431    10577
    cmph-chm     0.001325  0.000646 0.067026     4356    11057
    cmph-fch     0.001372  0.000511 0.066843      942    10177
    cmph-chd_ph  0.001310  0.000361 0.066292      418    10033
    cmph-chd     0.001323  0.000343 0.066428      735    10129
    switch       0.001190  0.000173 0.131323    12517    17450
    gperf        0.001199  0.002180 0.064883     8987    12574

=head1 AUTHOR

Reini Urban C<rurban@cpanel.net> 2014

=head1 LICENSE

Copyright 2014 cPanel Inc
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

&_test(@ARGV) unless caller;

# usage: perl -Ilib lib/Perfect/Hash.pm
sub _test {
  my (@dict, %dict);
  my $dict = shift || "examples/words20"; #"/usr/share/dict/words";
  my $method = shift || "";
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
    #printf "hash(0,\"%s\") = %x\n", $word, $ph->hash(0, $word);
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

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 2
#   fill-column: 78
# End:
# vim: expandtab shiftwidth=4:
