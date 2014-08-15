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

There exist various C and a primitive python library to generate code to
access perfect hashes and minimal versions thereof, but nothing to use
easily. C<gperf> is not very well suited to create big maps and cannot deal
with anagrams, but creates fast C code. C<Pearson> hashes are simplier and
fast for small machines, but not guaranteed to be creatable for small or
bigger hashes.  cmph C<CHD> and the other cmph algorithms might be the best
algorithms for big hashes, but lookup time is slower for smaller hashes and
you need to link to an external library.

As input we need to provide a set of unique keys, either as arrayref or
hashref or as keyfile. The keys can so far only be strings (will be extended
to ints on demand) and the values can so far be only ints and strings.  More
types later.

As generation algorithm there exist various hashing methods:
Hanov, HanovPP, Urban, CMPH::*, Bob, Pearson, Gperf, Cuckoo, Switch, ...

As output there exist several output formater classes, e.g. C, XS or
you can create your own for any language e.g. Java, Ruby, PHP, Python,
PECL...

The best algorithm used in Hanov and various others is derived from
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
L<http://cmph.sourceforge.net/papers/esa09.pdf>

=head1 METHODS

=over

=item new hashref|arrayref|keyfile, algo, options...

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

=item -minimal (not yet)

Selects the best available method for a minimal hash, given the
dictionary size, the options, and if the compiled algos are available.

=item -false-positives

Do not store the keys of the hash. Needs much less space and is faster, but
might only be used either if you know in advance that you'll never lookup not
existing keys, or check the result manually by yourself to avoid false
positives.

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

Strict variant of a 8-bit (256 byte) Pearson hash table.  Generates
very fast lookup, but limited dictionaries with a 8-bit pearson table
for 5-255 keys.  Returns undef for invalid dictionaries.

=item -switch

This is similar to -pearson8 only recommended for small dictionary
sizes < 256. Generates a nested switch table first switching on the
size and then on the keys.

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

=item -bob (not yet)

Nice and easy.

=item -gperf (not yet)

Pretty fast lookup, but limited dictionaries.

=item -cmph-bdz_ph

The C<-cmph-*> methods are the current state of the art for bigger
dictionaries.  This needs the external cmph library even at run-time.

The performance depends on the dictionary size.
-cmph-bdz_ph is usually the fastest cmph method for
1.000 - 250.000 keys.

=item -cmph-bdz

=item -cmph-bmz

=item -cmph-chm

=item -cmph-fch

=item -cmph-chd_ph

=item -cmph-chd

=item -for-c (yet unused)

Optimize for C libraries

=item -for-xs (yet unused)

Optimize for shared Perl XS code. Stores the values as perl types.

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
comparison. Note that locale dependent case mappings are done via
C<libicu>.

=back

=cut

# Not yet:      Bob Gperf
#               CMPH::BMZ8 CMPH::BRZ
our @algos = qw(HanovPP Hanov Urban Pearson8 Pearson PearsonNP
                CMPH::BDZ_PH CMPH::BDZ CMPH::BMZ CMPH::CHM
                CMPH::FCH CMPH::CHD_PH CMPH::CHD
              );
# Still failing:
our %algo_todo = map {$_=>1} # pure-perl and save_c
  qw(-cmph-bdz_ph -cmph-bdz -cmph-bmz -cmph-chm -cmph-fch -cmph-chd_ph -cmph-chd -cmph-bmz8 -cmph-brz);
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

linux/amd64 with a dictionary size=99171 and Intel Core i5-2300 CPU @ 2.80GHz
with native iSCSI CRC32-C from zlib.
Note that searching for utf8 keys is still broken.

    size=99171, lookups=19834  (smaller sec and size is better)
    Method       *lookup*  generate compile   c size   exesize  options
    hanovpp      0.003559  1.500453 0.686831  1199116  1069340  -false-positives -nul
    hanov        0.004246  0.802108 0.685475  1197842  1069442  -false-positives -nul
    urban        0.004258  0.912100 0.800518  1197842  1069442  -false-positives -nul
    pearson      0.007302  60.782395 4.279730  8531573  7870287  -false-positives -nul
    pearsonnp    0.010261  10.924107 1.838053  2647938  3916273  -false-positives -nul
    ----
    hanovpp      0.005107  1.759427 1.600238  2393770  2592567  -nul
    			with 189 errors.
    hanov        0.005396  0.973060 1.612685  2392496  2592637  -nul
    			with 122 errors.
    urban        0.005363  1.041718 1.731006  2392496  2592637  -nul
    			with 122 errors.
    pearson      0.007824  61.046319 5.160074  9726231  8905519  -nul
    			with 189 errors.
    pearsonnp    0.010437  10.981826 2.532491  3842596  4708496  -nul
    			with 189 errors.
    cmph-bdz_ph  0.006023  0.051516 0.205664    67005   300257  -nul
    			with 122 errors.
    cmph-bdz     0.008608  0.049154 0.211789    98105   310169  -nul
    			with 122 errors.
    cmph-bmz     0.007910  0.128633 0.328867  1590581   732057  -nul
    			with 122 errors.
    cmph-chm     0.008509  0.085596 0.459539  3074289  1104945  -nul
    			with 122 errors.
    cmph-fch     0.007814  12.502236 0.215060   196138   334497  -nul
    			with 122 errors.
    cmph-chd_ph  0.008144  0.039556 0.210535    36047   288129  -nul
    			with 122 errors.
    cmph-chd     0.010228  0.044528 0.212329   141652   328777  -nul
    			with 122 errors.
    ----
    hanovpp      0.004833  1.846433 0.701910  1199133  1069356  -false-positives
    hanov        0.005344  1.039758 0.691065  1197859  1069434  -false-positives
    urban        0.005060  1.096482 0.786573  1197859  1069434  -false-positives
    pearson      0.008008  61.140093 4.385373  8531600  7870286  -false-positives
    pearsonnp    0.010480  11.017392 1.845092  2647965  3916273  -false-positives
    ----
    hanovpp      0.005233  1.815628 1.611002  2393787  2592575  
    			with 189 errors.
    hanov        0.005842  1.023560 1.597355  2392513  2592629  
    			with 122 errors.
    urban        0.005623  1.099580 1.734883  2392513  2592629  
    			with 122 errors.
    pearson      0.007954 61.131227 5.142186  9726258  8905518  
    			with 122 errors.
    pearsonnp    0.010176 11.073165 2.532958  3842623  4708496  
    			with 122 errors.
    cmph-bdz_ph  0.006179  0.051152 0.202600    66648   300257  
    			with 122 errors.
    cmph-bdz     0.007714  0.048990 0.205134    97679   310169  
    			with 122 errors.
    cmph-bmz     0.007925  0.086077 0.318825  1589301   732057  
    			with 121 errors.
    cmph-chm     0.008619  0.293717 0.441057  3073424  1104945  
    			with 122 errors.
    cmph-fch     0.007941  3.345252 0.210624   196252   334497  
    			with 122 errors.
    cmph-chd_ph  0.008241  0.039189 0.200733    35935   288105  
    			with 122 errors.
    cmph-chd     0.010375  0.044615 0.206307   142312   328777  
    			with 122 errors.

Medium sized dictionary with 2000 keys:

    hanovpp      0.001686  0.029126 0.102906    47332    56335  -nul
    			with 143 errors.
    hanov        0.001780  0.012525 0.105465    47018    56405  -nul
    			with 143 errors.
    urban        0.001683  0.015771 0.105878    47018    56405  -nul
    			with 143 errors.
    pearson      0.001708 17.683428 0.158598   187056   172285  -nul
    			with 143 errors.
    pearsonnp    0.001757  0.229568 0.131471   109984   135184  -nul
    			with 143 errors.

Small dictionary with 127 keys:

    hanovpp      0.001691  0.001588 0.077698     3536    10799  -nul
    			with 23 errors.
    hanov        0.001720  0.000938 0.077489     3263    10869  -nul
    			with 23 errors.
    urban        0.001760  0.001068 0.077163     3263    10869  -nul
    			with 23 errors.
    pearson      0.001706  0.072921 0.079308    12413    18425  -nul
    			with 23 errors.
    pearsonnp    0.001742  0.018580 0.078671    12299    18498  -nul
    			with 23 errors.

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
