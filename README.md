# NAME

Perfect::Hash - generate perfect hashes

# SYNOPSIS

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

# DESCRIPTION

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
[http://cmph.sourceforge.net/papers/esa09.pdf](http://cmph.sourceforge.net/papers/esa09.pdf)

As input we need to provide a set of unique keys, either as arrayref
or hashref.

WARNING: When querying a perfect hash you need to be sure that key
really exists on some algorithms, as non-existing keys might return
false positives.  If you are not sure how the perfect hash deals with
non-existing keys, you need to check the result manually as in the
SYNOPSIS.  It's still faster than using a Bloom filter though.

As generation algorithm there exist various hashing classes,
e.g. Hanov, CMPH::\*, Bob, Pearson, Gperf.

As output there exist several dumper classes, e.g. C, XS or
you can create your own for any language e.g. Java, Ruby, ...

# METHODS

- new hashref|arrayref, algo, options...

    Evaluate the best algorithm given the dict size and output options and 
    generate the minimal perfect hash for the given keys. 

    The values in the dict are not needed to generate the perfect hash function,
    but might be needed later. So you can use either an arrayref where the index
    is returned, or a full hashref.

    Options for output classes are prefixed with `-for-`,
    e.g. `-for-c`. They might be needed to make a better decision which
    perfect hash to use.

    The following algorithms and options are planned:

    - \-hanovpp (default, pure perl)
    - \-optimal-size

        tries various hashes, and uses the one which will create the smallest
        hash in memory. Those hashes usually will not store the value, so you
        need to check the result for a false-positive.

    - \-optimal-speed

        tries various hashes, and uses the one which will use the fastest
        lookup.

    - \-minimal

        Selects the best available method for a minimal hash, given the
        dictionary size, the options, and if the compiled algos are available.

    - \-bob
    - \-gperf
    - \-pearson
    - \-cmph-chd
    - \-cmph-bdz
    - \-cmph-brz
    - \-cmph-chm
    - \-cmph-fch
    - \-for-c
    - \-for-xs
    - \-for-sharedlib

- perfecthash $obj, $key

    Returns the index into the arrayref, resp. the provided hash value.

- false\_positives

    Returns 1 if perfecthash might return false positives. I.e. You'll need to check
    the result manually again.

- save\_c

    See ["save_c" in Perfect::Hash::C](https://metacpan.org/pod/Perfect::Hash::C#save_c)

- save\_xs

    See ["save_xs" in Perfect::Hash::xs](https://metacpan.org/pod/Perfect::Hash::xs#save_xs)

# SEE ALSO

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
