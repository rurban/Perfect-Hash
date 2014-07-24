#!/usr/bin/python
# Easy Perfect Minimal Hashing 
# By Steve Hanov. Released to the public domain.
# http://stevehanov.ca/blog/index.php?id=119
#
# Based on:
# Edward A. Fox, Lenwood S. Heath, Qi Fan Chen and Amjad M. Daoud, 
# "Practical minimal perfect hash functions for large databases", CACM, 35(1):105-121
# also a good reference:
# Compress, Hash, and Displace algorithm by Djamal Belazzougui,
# Fabiano C. Botelho, and Martin Dietzfelbinger
import sys

DICTIONARY = "/usr/share/dict/words"
#DICTIONARY = "words20"
TEST_WORDS = sys.argv[1:]
if len(TEST_WORDS) == 0:
    if DICTIONARY == "words20":
        TEST_WORDS = ['ASL\'s', 'AWOL\'s', 'AZT\'s', 'Aachen']
    else:
        TEST_WORDS = ['hello', 'goodbye', 'dog', 'cat']

# Calculates a distinct hash function for a given string. Each value of the
# integer d results in a different hash value.
def hash( d, str ):
    if d == 0: d = 0x01000193

    # Use the FNV algorithm from http://isthe.com/chongo/tech/comp/fnv/ 
    for c in str:
        d = ( (d * 0x01000193) ^ ord(c) ) & 0xffffffff;

    return d

# Computes a minimal perfect hash table using the given python dictionary. It
# returns a tuple (G, V). G and V are both arrays. G contains the intermediate
# table of values needed to compute the index of the value in V. V contains the
# values of the dictionary.
def CreateMinimalPerfectHash( dict ):
    size = len(dict)

    # Step 1: Place all of the keys into buckets
    buckets = [ [] for i in range(size) ]
    G = [0] * size
    values = [None] * size
    
    for key in dict.keys():
        buckets[hash(0, key) % size].append( key )

    # Step 2: Sort the buckets and process the ones with the most items first.
    buckets.sort( key=len, reverse=True )        
    for b in xrange( size ):
        bucket = buckets[b]
        if len(bucket) <= 1: break
        
        d = 1
        item = 0
        slots = []

        # Repeatedly try different values of d until we find a hash function
        # that places all items in the bucket into free slots
        while item < len(bucket):
            slot = hash( d, bucket[item] ) % size
            if values[slot] != None or slot in slots:
                d += 1
                item = 0
                slots = []
            else:
                slots.append( slot )
                item += 1

        G[hash(0, bucket[0]) % size] = d
        for i in range(len(bucket)):
            values[slots[i]] = dict[bucket[i]]

        if ( b % 1000 ) == 0:
            print "bucket %d    r\n" % (b),
            sys.stdout.flush()

    # Only buckets with 1 item remain. Process them more quickly by directly
    # placing them into a free slot. Use a negative value of d to indicate
    # this.
    freelist = []
    for i in xrange(size): 
        if values[i] == None: freelist.append( i )

    print "xrange(%d, %d)\n" % (b, size),
    for b in xrange( b, size ):
        bucket = buckets[b]
        if len(bucket) == 0: break
        slot = freelist.pop()
        # We subtract one to ensure it's negative even if the zeroeth slot was
        # used.
        G[hash(0, bucket[0]) % size] = -slot-1 
        values[slot] = dict[bucket[0]]
        if ( b % 1000 ) == 0:
            print "bucket %d    r\n" % (b),
            sys.stdout.flush()

    return (G, values)        

# Look up a value in the hash table, defined by G and V.
def PerfectHashLookup( G, V, key ):
    d = G[hash(0,key) % len(G)]
    if d < 0: return V[-d-1]
    return V[hash(d, key) % len(V)]

print "Reading words"
dict = {}
line = 1
for key in open(DICTIONARY, "rt").readlines():
    dict[key.strip()] = line
    line += 1

print "Creating perfect hash"
(G, V) = CreateMinimalPerfectHash( dict )

for word in TEST_WORDS:
    line = PerfectHashLookup( G, V, word )
    print "Word %s occurs on line %d" % (word, line)
