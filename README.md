# NAME

Perfect::Hash - generate perfect hashes

# SYNOPSIS

    use Perfect::Hash;
    my @dict = split/\n/,`cat /usr/share.dict/words`;

    my $ph = Perfect::Hash->new(\@dict, -minimal);
    for (@ARGV) {
      print "$_ at line ",$ph->perfecthash($_);
    }

# DESCRIPTION

Perfect hashing is a technique for building a hash table with no
collisions. It is only possible to build one when we know all of the
keys in advance. Minimal perfect hashing implies that the resulting
table contains one entry for each key, and no empty slots.

There exist various C and a primitive python library to generate code
to access perfect hashes and minimal versions thereof, but nothing to
use easily. gperf is not very well suited to create big maps and cannot
deal with anagrams, but creates fast C code. pearson hashes are also
pretty fast, but not guaranteed to be creatable for small hashes.

The best algorithm for big hashes, CHD, is derived from 
"Compress, Hash, and Displace algorithm" by Djamal Belazzougui,
Fabiano C. Botelho, and Martin Dietzfelbinger
[http://cmph.sourceforge.net/papers/esa09.pdf](http://cmph.sourceforge.net/papers/esa09.pdf)

As input we need to provide a set of unique keys, either as arrayref
or hashref.

As generation algorithm there exist various hashing classes,
e.g. Hanov, CMPH, Bob, Pearsons, gperf.

As output there exist several dumper classes, e.g. C, XS, Perl or
you can create your own for any language e.g. Java, Ruby, ...

# METHODS

- new hashref|arrayref, algo, options...

    Evaluate the best algorithm given the dict size and outoput options and 
    Generate the minimal perfect hash for the given keys. 

    The values in the dict are not needed to generate the perfect hash function,
    but might be needed later. So you can use either an arrayref where the index
    is returned, or a full hashref.

    The following algorithms and options are planned:

    - \-hanov (default, pure perl)
    - \-bob
    - \-gperf
    - \-pearson
    - \-cmph-chd
    - \-cmph-bdz
    - \-cmph-brz
    - \-cmph-chm
    - \-cmph-fch
    - \-minimal 

        Selects the best available method for a minimal hash, given the dictionary size, 
        the options, and if the compiled methods are available.

    - \-for-c
    - \-for-sharedlib

- perfecthash $obj, $key

    Returns the index into the arrayref, resp. the provided hash value.


