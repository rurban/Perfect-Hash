/* -*- tab-width:4 mode:c -*- */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "zlib.h"

#if 0
# ifdef USE_PPPORT_H
#  define NEED_sv_2pvbyte
#  define NEED_sv_2pv_nolen
#  define NEED_sv_pvn_force_flags
#  include "ppport.h"
# endif
#endif

/* FNV algorithm from http://isthe.com/chongo/tech/comp/fnv/ */
static inline
unsigned fnv_hash_len (unsigned d, const char *s, const int l) {
    int c = *s++;
    int i = 0;
    if (!d) d = 0x01000193;
    for (; i < l; i++) {
        d = ((d * 0x01000193) ^ *s++) & 0xffffffff;
    }
    return d;
}

#define VEC(G, index, bits) (IV)((*(IV*)(G + ((index) * bits/8))) & ((1<<bits)-1))

IV vec(char *G, IV index, IV bits) {
  if (bits == 8)
    return *(char*)(G + index) & 255;
  else if (bits == 4)
    return *(char*)(G + (index / 2)) & 15;
  else if (bits == 16) {
    int l = *(int*)(G + index) & 65535;
    return (IV)l;
  }
  else if (bits == 32) {
    long l = *(long*)(G + index);
    return (IV)l;
  }
#ifdef HAVE_QUAD
  else if (bits == 64) {
    long long l = *(long long*)(G + index);
    return (IV)l;
  }
#endif
}

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Hanov

SV*
perfecthash(ph, key)
  SV* ph
  SV* key;
CODE:
    AV *ref = (AV*)SvRV(ph);
    AV *g = (AV*)SvRV(AvARRAY(ref)[0]);
    SV **ga = AvARRAY(g);
    UV size = AvFILL(g) + 1;
    SV **va = AvARRAY((AV*)SvRV(AvARRAY(ref)[1]));
    IV d  = SvIVX(ga[fnv_hash_len(0, SvPVX(key), SvCUR(key)) % size]);
    SV *v = d < 0 ? va[-d-1] : va[fnv_hash_len(d, SvPVX(key), SvCUR(key)) % size];
    if (AvFILL(ref) > 2) {
      SV **keys = AvARRAY((AV*)SvRV(AvARRAY(ref)[3]));
      IV iv = SvIVX(v);
      RETVAL = (SvCUR(key) == SvCUR(keys[iv]) && memEQ(SvPVX(keys[iv]), SvPVX(key), SvCUR(key)))
        ? SvREFCNT_inc_NN(v) : &PL_sv_undef;
    } else {
      RETVAL = SvREFCNT_inc_NN(v);
    }
OUTPUT:
    RETVAL

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Urban

# TODO: return SV* and store SV's in values, not just indices.
# use AV * V, not the 2nd half of SvPVX(G).

IV
iv_perfecthash(ph, key)
  SV* ph
  SV* key;
CODE:
    AV *ref = (AV*)SvRV(ph);
    SV *g = AvARRAY(ref)[0];
    char *G = SvPVX(g);
    IV bits = SvIVX(AvARRAY(ref)[1]);
    UV size = 4 * SvCUR(g) / bits; /* 40 = (20 * BITS / 4); 20 = 40 * 4 / BITS */
    char *V = SvPVX(g)+size;
    UV h = crc32(0, SvPVX(key), SvCUR(key)) % size;
    IV d = vec(G, h, bits);
    if (d >= 1<<(bits-1))
      d = (d - (1<<bits));
    IV v = d < 0
      ? vec(V, -d-1, bits)
      : d == 0 ? vec(V, h, bits)
               : vec(V, (UV)crc32(d, SvPVX(key), SvCUR(key)) % size, bits);
#ifdef DEBUGGING_PHASH
    if (hv_exists((HV*)SvRV(AvARRAY(ref)[2]), "-debug", 6)) {
      printf("\nxs: h0=%2d d=%3d v=%2d\t",h, d>0 ? crc32(d,SvPVX(key),SvCUR(key))%size : d, v);
    }
#endif
    if (v > size) {
#ifdef DEBUGGING
      assert(v<size);
#endif
      RETVAL = -1;
    }
    else if (AvFILL(ref) > 2) {
      SV **keys = AvARRAY((AV*)SvRV(AvARRAY(ref)[3]));
      RETVAL = (SvCUR(key) == SvCUR(keys[v]) && memEQ(SvPVX(keys[v]), SvPVX(key), SvCUR(key)))
        ? v : -1;
    } else {
      RETVAL = v;
    }
OUTPUT:
    RETVAL

UV
hash(key, seed=0)
  SV* key
  UV  seed;
CODE:
    if (items < 2) {
      if (SvPOK(key))
        RETVAL = crc32(0, SvPVX(key), SvCUR(key));
      else
        RETVAL = crc32(0, NULL, 0);
    }
	else
	  RETVAL = crc32(seed, SvPVX(key), SvCUR(key));
OUTPUT:
    RETVAL
