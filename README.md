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

There exist various C and a simple python script to generate code to
access perfect hashes and minimal versions thereof, but nothing to use
easily. `gperf` is not very well suited to create big maps and cannot deal
with anagrams, but creates fast C code for small dictionaries.
`Pearson` hashes are simplier and fast for small machines, but not guaranteed
to be creatable for small or bigger hashes.  cmph `CHD`, `BDZ_PH` and the
other cmph algorithms might be the best algorithms for big hashes, but lookup
time is slower for smaller hashes and you need to link to an external library.

As input we need to provide a set of unique keys, either as arrayref or
hashref or as keyfile. The keys can so far only be strings (will be extended
to ints on demand) and the values can so far be only ints and strings.  More
types later.

As generation algorithm there exist various hashing methods:
Hanov, HanovPP, Urban, CMPH::\*, Bob, Pearson, Gperf, Cuckoo, Switch, ...

As output there exist several output formater classes, e.g. C and later: XS,
Java, Ruby, PHP, Python, PECL.  For Lua or Lisp this is probably not needed as
they either roll their own, or FFI into the generated C library.  For Go,
Rust, Scala, Clojure, etc just roll you own library, based on an existing one.

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
    is returned, or a full hashref or a keyfile as with `gperf`.

    Options for output classes are prefixed with `-for-`,
    e.g. `-for-c`. They might be needed to make a better decision which
    perfect hash to use.

    The following algorithms and options are done and planned:

    - \-false-positives

        Do not store the keys of the hash. Needs much less space and is faster, but
        might only be used either if you know in advance that you'll never lookup not
        existing keys, or check the result manually by yourself to avoid false
        positives.

    - \-minimal (not yet)

        Selects the best available method for a minimal hash, given the
        dictionary size, the options, and if the compiled algos are available.

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

        Generates nice and easy C code without external library dependency.
        However to generate -bob you need a C compiler.

    - \-gperf (not yet)

        Pretty fast lookup, but limited dictionaries.

    - \-cmph-bdz\_ph

        The `-cmph-*` methods are the current state of the art for bigger
        dictionaries.  This needs the external `cmph` library even at run-time.

        The performance depends on the dictionary size.
        \-cmph-bdz\_ph is usually the fastest cmph method for
        1.000 - 250.000 keys, and -cmph-chm is usually the second best option.

    - \-cmph-bdz
    - \-cmph-bmz
    - \-cmph-chm
    - \-cmph-fch
    - \-cmph-chd\_ph
    - \-cmph-chd
    - \-for-c (default)

        Optimize for C libraries

    - \-for-xs (not yet)

        Optimize for shared Perl XS code. Stores the values as perl types.

    - \-for-_class_ (not yet)

        Optimize for any _CLASS_ output formatter class, loaded dynamically.
        Such as PYTHON, RUBY, JAVA, PHP, PECL, ...

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

- hash\_murmur3 string, \[seed\]

    pure-perl murmur3 int32 finalizer

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

# BENCHMARKS

linux/amd64 with a dictionary size=99171, lookup every key.
with Intel Core i5-2300 CPU @ 2.80GHz with native iSCSI CRC32-C from zlib.

    size=99171  (smaller sec and size is better)
    Method       *lookup*  generate compile   c size   exesize  options
    hanovpp      0.006989  1.436367 1.351763  1199097  2434100  -false-positives -nul
    hanov        0.008307  0.804571 1.353573  1197842  2434154  -false-positives -nul
    urban        0.008450  0.911321 1.455943  1197842  2434154  -false-positives -nul
    pearson      0.020871 60.974142 5.006366  8527047  8744321  -false-positives -nul
                            with 244 errors.
    pearsonnp    0.083467 10.801427 2.635511  2647938  4551585  -false-positives -nul
                            with 119 errors.
    ----
    hanovpp      0.009675  1.689798 2.213405  2393751  3227319  -nul
    hanov        0.010605  0.968302 2.176248  2392496  3227389  -nul
    urban        0.010532  1.039979 2.324133  2392496  3227389  -nul
    pearson      0.023665 61.169050 5.660405  9722900  9538005  -nul
                            with 232 errors.
    pearsonnp    0.088344 10.980605 3.129068  3842596  5343376  -nul
                            with 220 errors.
    cmph-bdz_ph  0.017992  0.054180 0.932670    67005  1664617  -nul
                            with 97 errors.
    cmph-bdz     0.023886  0.057615 0.872904    98105  1674529  -nul
                            with 98 errors.
    cmph-bmz     0.025001  0.121611 0.981429  1590581  2096417  -nul
                            with 99 errors.
    cmph-chm     0.027271  0.080735 1.120437  3074289  2469305  -nul
    cmph-fch     0.026378  12.378517 0.872177   196138  1698857  -nul
                            with 99 errors.
    cmph-chd_ph  0.027743  0.039562 0.850820    36049  1652489  -nul
                            with 99 errors.
    cmph-chd     0.038430  0.045187 0.852698   141652  1692769  -nul
                            with 99 errors.
    ----
    hanovpp      0.008010  1.759084 1.352361  1199114  2434100  -false-positives
    hanov        0.009259  1.024201 1.336644  1197859  2434154  -false-positives
    urban        0.009543  1.094011 1.471859  1197859  2434154  -false-positives
    pearson      0.017978 60.941614 4.871941  8526699  8746009  -false-positives
    pearsonnp    0.086658 11.000568 2.427189  2647965  4551705  -false-positives
    ----
    hanovpp      0.010562  1.751556 2.214865  2393768  3227327
    hanov        0.010598  1.016665 2.193283  2392513  3227381
    urban        0.010507  1.086292 2.311609  2392513  3227381
    pearson      0.019339 61.244146 5.683251  9709707  9534345
    pearsonnp    0.083965 11.032944 3.129065  3842623  5346576
    cmph-bdz_ph  0.017602  0.052354 0.835667    66648  1664617
                            with 98 errors.
    cmph-bdz     0.023596  0.050567 0.855532    97679  1674529
                            with 98 errors.
    cmph-bmz     0.026002  0.086047 0.980673  1589301  2096417
                            with 98 errors.
    cmph-chm     0.027161  0.294937 1.091579  3073424  2469305
    cmph-fch     0.026335  3.315327 0.844936   196255  1698857
                            with 99 errors.
    cmph-chd_ph  0.027760  0.039251 0.845953    35938  1652465
                            with 98 errors.
    cmph-chd     0.038633  0.044931 0.854745   142315  1692801
                            with 99 errors.
    ----

Medium sized dictionary with 2000 keys:
`perl -Mblib examples/bench.pl -size 2000 -nul`

    hanovpp      0.001290  0.024794 0.113399    43698    65615  -nul
    hanov        0.001334  0.013031 0.115256    43404    65685  -nul
    urban        0.001380  0.014536 0.116168    43404    65685  -nul
    pearson      0.001327 15.854757 0.172386   181564   181210  -nul
                            with 15 errors.
    pearsonnp    0.001424  0.210114 0.145279   102931   143328  -nul
                            with 15 errors.

Small dictionary with 127 keys:

    hanovpp      0.001163  0.001839 0.076842     3437    11567  -nul
    hanov        0.001288  0.001723 0.077527     3183    11637  -nul
    urban        0.001235  0.002297 0.077904     3183    11637  -nul
    pearson      0.001150  0.070689 0.079403    12405    19236  -nul
    pearsonnp    0.001197  0.018541 0.079585    12094    19167  -nul

# AUTHOR

Reini Urban `rurban@cpanel.net` 2014

# LICENSE

Copyright 2014 cPanel Inc
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
