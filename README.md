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

Perfect hashing is a technique for building a static hash table with no
collisions. Which means guaranteed constant O(1) access time, and for
minimal perfect hashes guaranteed minimal size. It is only possible to
build one when we know all of the keys in advance. Minimal perfect
hashing implies that the resulting table contains one entry for each
key, and no empty slots.

There exist various C and a primitive python library to generate code
to access perfect hashes and minimal versions thereof, but nothing to
use easily. `gperf` is not very well suited to create big maps and
cannot deal with anagrams, but creates fast C code. `Pearson` hashes
are simplier and even faster, but not guaranteed to be creatable for
small or bigger hashes.  cmph `CHD` and the other cmph algorithms
might be the best algorithms for big hashes, but lookup time is slower
for smaller hashes.

As input we need to provide a set of unique keys, either as arrayref
or hashref.

WARNING: When querying a perfect hash you need to be sure that the key
really exists on some algorithms, as querying for non-existing keys
might return false positives.  If you are not sure how the perfect
hash deals with non-existing keys, you need to check the result
manually as in the SYNOPSIS or use the option `-no-false-positives`
to store the values also. It's still faster than using a Bloom filter
though.

As generation algorithm there exist various hashing classes,
e.g. Hanov, CMPH::\*, Bob, Pearson, Gperf.

As output there exist several dumper classes, e.g. C, XS or
you can create your own for any language e.g. Java, Ruby, ...

The best algorithm for big hashes, CHD, is derived from
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
[http://cmph.sourceforge.net/papers/esa09.pdf](http://cmph.sourceforge.net/papers/esa09.pdf)

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

    - \-minimal (not yet)

        Selects the best available method for a minimal hash, given the
        dictionary size, the options, and if the compiled algos are available.

    - \-no-false-positives

        Stores the values with the hash also, and checks the found key against
        the value to avoid false positives. Needs much more space.

    - \-optimal-size (not yet)

        Tries various hashes, and uses the one which will create the smallest
        hash in memory. Those hashes usually will not store the value, so you
        might need to check the result for a false-positive.

    - \-optimal-speed (not yet)

        Tries various hashes, and uses the one which will use the fastest
        lookup.

    - \-hanovpp

        Default pure perl method.

    - \-urban

        Improved version of HanovPP, using compressed temp. arrays and
        optimized XS methods, ~2x faster (zlib crc32) and 300x smaller than
        HanovPP.  Can only store index values, not strings.

    - \-pearson8

        Strict variant of a 8-bit (256 byte) Pearson hash table.  Generates
        very fast lookup, but limited dictionaries with a 8-bit pearson table
        for 5-255 keys.  Returns undef for invalid dictionaries.

    - \-pearson

        Non-perfect variant with adjusted pearson table size.
        Try to find a n-bit sized pearson table for the given
        dictionary. Keeps the best found hash table, with no guarantees that
        it is a perfect hash table.
        If not, collision resolution is done via static binary trees.

        This version generates arbitrary sized pearson lookup tables and thus
        should be able to find a perfect hash, but success is very
        unlikely. The generated lookup might be however still faster than most
        other hash tables for <100.000 keys.

    - \-pearsonnp

        "np" for non-perfect. Try to find a 8-bit (256 byte) sized pearson
        table for the given dictionary. Keeps the best found hash table, with
        no guarantees that it is a perfect hash table.  If not, collision
        resolution is done via static binary trees.

        This is also a very fast variant as the 256 byte table is guaranteed to
        fit into every CPU cache.

    - \-bob (not yet)

        Nice and easy.

    - \-gperf (not yet)

        Pretty fast lookup, but limited dictionaries.

    - \-cmph-chd (not yet)

        The current state of the art for bigger dictionaries.

    - \-cmph-bdz (not yet)
    - \-cmph-brz (not yet)
    - \-cmph-chm (not yet)
    - \-cmph-fch (not yet)
    - \-for-c

        Optimize for C libraries

    - \-for-xs

        Optimize for shared Perl XS code. Stores the values as perl types.

    - \-hash=`name` (not yet)

        Use the specified hash function instead of the default.
        Only useful for hardware assisted `crc32` and `aes` system calls,
        provided by compiler intrinsics (sse4.2) or libz.
        See -hash=help for a list of all supported hash function names:
        `crc32`, `aes`, `crc32-libz`

        The hardware assisted `crc32` and `aes` functions add a run-time
        probe with slow software fallback code.  `crc32-libz` does all this
        also, and is especially optimized for long keys to hash them in
        parallel.

    - \-pic (not yet)

        Optimize the generated table for inclusion in shared libraries via a
        constant stringpool. This reduces the startup time of programs using a
        shared library containing the generated code. As with [gperf](https://metacpan.org/pod/gperf)
        `--pic`

    - \-nul

        Allow `NUL` bytes in keys, i.e. store the length for keys and compare
        binary via `strncmp`.

    - \-null-strings

        Use `NULL` strings instead of empty strings for empty keyword table
        entries. This reduces the startup time of programs using a shared
        library containing the generated code (but not as much as the
        declaration `-pic` option), at the expense of one more
        test-and-branch instruction at run time.

    - \-7bit

        Guarantee that all keys consist only of 7-bit ASCII characters, bytes
        in the range 0..127.

    - \-ignore-case

        Consider upper and lower case ASCII characters as equivalent. The
        string comparison will use a case insignificant character
        comparison. Note that locale dependent case mappings are ignored.

    - \-unicode-ignore-case

        Consider upper and lower case unicode characters as equivalent. The
        string comparison will use a case insignificant character
        comparison. Note that locale dependent case mappings are done via
        `libicu`.

- perfecthash $key

    Returns the index into the arrayref, resp. the provided hash value.

- false\_positives

    Returns 1 if perfecthash might return false positives. I.e. You'll need to check
    the result manually again.

- save\_c fileprefix, options

    See ["save_c" in Perfect::Hash::C](https://metacpan.org/pod/Perfect::Hash::C#save_c)

- save\_xs file, options

    See ["save_xs" in Perfect::Hash::XS](https://metacpan.org/pod/Perfect::Hash::XS#save_xs)

# SEE ALSO

`script/phash` for the frontend.

## Algorithms

[Perfect::Hash::HanovPP](https://metacpan.org/pod/Perfect::Hash::HanovPP),
[Perfect::Hash::Pearson](https://metacpan.org/pod/Perfect::Hash::Pearson),
[Perfect::Hash::Pearson8](https://metacpan.org/pod/Perfect::Hash::Pearson8),
[Perfect::Hash::PearsonNP](https://metacpan.org/pod/Perfect::Hash::PearsonNP),
[Perfect::Hash::Urban](https://metacpan.org/pod/Perfect::Hash::Urban),
[Perfect::Hash::Bob](https://metacpan.org/pod/Perfect::Hash::Bob),
[Perfect::Hash::Gperf](https://metacpan.org/pod/Perfect::Hash::Gperf),
[Perfect::Hash::CMPH::CHD](https://metacpan.org/pod/Perfect::Hash::CMPH::CHD),
[Perfect::Hash::CMPH::BDZ](https://metacpan.org/pod/Perfect::Hash::CMPH::BDZ),
[Perfect::Hash::CMPH::BRZ](https://metacpan.org/pod/Perfect::Hash::CMPH::BRZ),
[Perfect::Hash::CMPH::CHM](https://metacpan.org/pod/Perfect::Hash::CMPH::CHM),
[Perfect::Hash::CMPH::FCH](https://metacpan.org/pod/Perfect::Hash::CMPH::FCH)

## Output classes

[Perfect::Hash::C](https://metacpan.org/pod/Perfect::Hash::C),
[Perfect::Hash::XS](https://metacpan.org/pod/Perfect::Hash::XS)
