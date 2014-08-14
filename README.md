# NAME

Perfect::Hash - generate perfect hashes, library backend for phash

# SYNOPSIS

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

# DESCRIPTION

Perfect hashing is a technique for building a static hash table with no
collisions. Which means guaranteed constant O(1) access time, and for minimal
perfect hashes even guaranteed minimal size. It is only possible to build one
when we know all of the keys in advance. Minimal perfect hashing implies that
the resulting table contains one entry for each key, and no empty slots.

There exist various C and a primitive python library to generate code to
access perfect hashes and minimal versions thereof, but nothing to use
easily. `gperf` is not very well suited to create big maps and cannot deal
with anagrams, but creates fast C code. `Pearson` hashes are simplier and
fast for small machines, but not guaranteed to be creatable for small or
bigger hashes.  cmph `CHD` and the other cmph algorithms might be the best
algorithms for big hashes, but lookup time is slower for smaller hashes and
you need to link to an external library.

As input we need to provide a set of unique keys, either as arrayref or
hashref or as keyfile. The keys can so far only be strings (will be extended
to ints on demand) and the values can so far be only ints and strings.  More
types later.

As generation algorithm there exist various hashing methods:
Hanov, HanovPP, Urban, CMPH::\*, Bob, Pearson, Gperf, Cuckoo, Switch, ...

As output there exist several output formater classes, e.g. C, XS or
you can create your own for any language e.g. Java, Ruby, PHP, Python,
PECL...

The best algorithm used in Hanov and various others is derived from
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
[http://cmph.sourceforge.net/papers/esa09.pdf](http://cmph.sourceforge.net/papers/esa09.pdf)

# METHODS

- new hashref|arrayref|keyfile, algo, options...

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

    - \-false-positives

        Do not store the keys of the hash. Needs much less space and is faster, but
        might only be used either if you know in advance that you'll never lookup not
        existing keys, or check the result manually by yourself to avoid false
        positives.

    - \-optimal-size (not yet)

        Tries various hashes, and uses the one which will create the smallest
        hash in memory. Those hashes usually will not store the value, so you
        might need to check the result for a false-positive.

    - \-optimal-speed (not yet)

        Tries various hashes, and uses the one which will use the fastest
        lookup.

    - \-hanovpp

        The default pure perl method.

    - \-hanov

        Improved version of HanovPP, using optimized XS methods,
        2-3x faster with HW supported iSCSI CRC32 (via zlib or manually).

        The fast hash function requires a relatively new 64bit Intel, AMD or ARM
        processor.  This might need the external zlib library (-lz) at run-time.

    - \-urban

        Improved version of Hanov, using compressed temp. arrays and
        the same optimized XS methods and hash functionsas in -hanov.
        But can only store index values in a limited range, not strings.

    - \-pearson8

        Strict variant of a 8-bit (256 byte) Pearson hash table.  Generates
        very fast lookup, but limited dictionaries with a 8-bit pearson table
        for 5-255 keys.  Returns undef for invalid dictionaries.

    - \-switch

        This is similar to -pearson8 only recommended for small dictionary
        sizes < 256. Generates a nested switch table first switching on the
        size and then on the keys.

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

    - \-cmph-bdz\_ph

        The `-cmph-*` methods are the current state of the art for bigger
        dictionaries.  This needs the external cmph library even at run-time.

        The performance depends on the dictionary size.
        \-cmph-bdz\_ph is usually the fastest cmph method for
        1.000 - 250.000 keys.

    - \-cmph-bdz
    - \-cmph-bmz
    - \-cmph-chm
    - \-cmph-fch
    - \-cmph-chd\_ph
    - \-cmph-chd
    - \-for-c (yet unused)

        Optimize for C libraries

    - \-for-xs (yet unused)

        Optimize for shared Perl XS code. Stores the values as perl types.

    - \-hash=`name` (not yet)

        Use the specified hash function instead of the default.
        Only useful for hardware assisted `crc32` and `aes` system calls,
        provided by compiler intrinsics (sse4.2) or libz. Note that some
        zlib libraries do not provide a HW-assisted fast crc32 function,
        rather a slow SW variant.
        See -hash=help for a list of all supported hash function names:
        `crc32_zlib`, `fnv`, `crc32_sse42`, `aes`, ...

        The hardware assisted `crc32` and `aes` functions add a run-time probe with
        slow software fallback code (not yet). `crc32_zlib` does all this also, and
        is especially optimized for long keys to hash them in parallel, if implemented
        in your library.

    - \-pic (not yet)

        Optimize the generated table for inclusion in shared libraries via a
        constant stringpool. This reduces the startup time of programs using a
        shared library containing the generated code. As with [gperf](https://metacpan.org/pod/gperf)
        `--pic`

    - \-nul

        Allow `NUL` bytes in keys, i.e. store the length for keys and compare
        binary via `memcmp`, not `strcmp`.

    - \-null-strings (not yet)

        Use `NULL` strings instead of empty strings for empty keyword table
        entries without `-false-positives`. This reduces the startup time of
        programs using a shared library containing the generated code (but not
        as much as the declaration `-pic` option), at the expense of one more
        test-and-branch instruction at run time.

    - \-7bit (not yet)

        Guarantee that all keys consist only of 7-bit ASCII characters, bytes
        in the range 0..127.

    - \-ignore-case (not yet)

        Consider upper and lower case ASCII characters as equivalent. The
        string comparison will use a case insignificant character
        comparison. Note that locale dependent case mappings are ignored.

    - \-unicode-ignore-case (not yet)

        Consider upper and lower case unicode characters as equivalent. The
        string comparison will use a case insignificant character
        comparison. Note that locale dependent case mappings are done via
        `libicu`.

- analyze\_data $dict, @options

    Scans the given dictionary, honors the given options and current architecture
    and returns the name of the recommended hash table algorithm for fast lookups.

- perfecthash $key

    Returns the index into the arrayref, resp. the provided hash value.

- false\_positives

    Returns 1 if perfecthash might return false positives.  I.e. will return the
    index of an existing key when you searched for a non-existing key. Then you'll
    need to check the result manually again.

    The default is undef, unless you created the hash with the option
    `-false-positives`.

- save\_c fileprefix, options

    See ["save_c" in Perfect::Hash::C](https://metacpan.org/pod/Perfect::Hash::C#save_c)

- save\_xs file, options

    See ["save_xs" in Perfect::Hash::XS](https://metacpan.org/pod/Perfect::Hash::XS#save_xs)

# SEE ALSO

`script/phash` for the frontend.

## Algorithms

[Perfect::Hash::HanovPP](https://metacpan.org/pod/Perfect::Hash::HanovPP),
[Perfect::Hash::Hanov](https://metacpan.org/pod/Perfect::Hash::Hanov),
[Perfect::Hash::Urban](https://metacpan.org/pod/Perfect::Hash::Urban),
[Perfect::Hash::Pearson](https://metacpan.org/pod/Perfect::Hash::Pearson),
[Perfect::Hash::Pearson8](https://metacpan.org/pod/Perfect::Hash::Pearson8),
[Perfect::Hash::PearsonNP](https://metacpan.org/pod/Perfect::Hash::PearsonNP),
[Perfect::Hash::Bob](https://metacpan.org/pod/Perfect::Hash::Bob) _(not yet)_,
[Perfect::Hash::Gperf](https://metacpan.org/pod/Perfect::Hash::Gperf) _(not yet)_,
[Perfect::Hash::CMPH::CHM](https://metacpan.org/pod/Perfect::Hash::CMPH::CHM),
[Perfect::Hash::CMPH::BMZ](https://metacpan.org/pod/Perfect::Hash::CMPH::BMZ),
[Perfect::Hash::CMPH::BMZ8](https://metacpan.org/pod/Perfect::Hash::CMPH::BMZ8) _(not yet)_,
[Perfect::Hash::CMPH::BRZ](https://metacpan.org/pod/Perfect::Hash::CMPH::BRZ) _(not yet)_,
[Perfect::Hash::CMPH::FCH](https://metacpan.org/pod/Perfect::Hash::CMPH::FCH)
[Perfect::Hash::CMPH::BDZ](https://metacpan.org/pod/Perfect::Hash::CMPH::BDZ),
[Perfect::Hash::CMPH::BDZ_PH](https://metacpan.org/pod/Perfect::Hash::CMPH::BDZ_PH),
[Perfect::Hash::CMPH::CHD](https://metacpan.org/pod/Perfect::Hash::CMPH::CHD),
[Perfect::Hash::CMPH::CHD_PH](https://metacpan.org/pod/Perfect::Hash::CMPH::CHD_PH)

## Output classes

Output classes are loaded dynamically from a `-for-class` option,
the option must be lowercase, the classsname must be uppercase.

[Perfect::Hash::C](https://metacpan.org/pod/Perfect::Hash::C) `-for-c` (C library)

[Perfect::Hash::XS](https://metacpan.org/pod/Perfect::Hash::XS) `-for-xs` (compiled perl extension)

Planned:

[Perfect::Hash::PYTHON](https://metacpan.org/pod/Perfect::Hash::PYTHON) `-for-python` (compiled python extension)

[Perfect::Hash::RUBY](https://metacpan.org/pod/Perfect::Hash::RUBY) `-for-ruby` (compiled ruby extension)

[Perfect::Hash::JAVA](https://metacpan.org/pod/Perfect::Hash::JAVA) `-for-java`

[Perfect::Hash::PHP](https://metacpan.org/pod/Perfect::Hash::PHP) `-for-php` (pure php)

[Perfect::Hash::PECL](https://metacpan.org/pod/Perfect::Hash::PECL) `-for-pecl` (compiled php extension)

For Lua or Lisp this is probably not needed as they either roll their own,
or FFI into the generated C library.
For Go, Rust, Scala, Clojure, etc just roll you own library, based on an
existing one.

# TEST REPORTS

CPAN Testers: [http://cpantesters.org/distro/P/Perfect-Hash](http://cpantesters.org/distro/P/Perfect-Hash)

[![Travis](https://travis-ci.org/rurban/Perfect-Hash.png)](https://travis-ci.org/rurban/Perfect-Hash/)

[![Coveralls](https://coveralls.io/repos/rurban/Perfect-Hash/badge.png)](https://coveralls.io/r/rurban/Perfect-Hash?branch=master)

# AUTHOR

Reini Urban `rurban@cpanel.net` 2014

# LICENSE

Copyright 2014 cPanel Inc
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
