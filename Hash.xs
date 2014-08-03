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

#define VEC(G, index, bits) (*(IV*)((G + (index * bits/8))) & (1<<bits)-1)

# TODO: return SV* and store SV's in values, not just indices.
# use AV * V, not the 2nd half of SvPVX(G).

IV
perfecthash(ph, key)
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
    IV d = VEC(G, bits, h);
    IV v = d < 0
      ? VEC(V, -d-1, bits)
      : d == 0 ? VEC(V, h, bits)
               : VEC(V, crc32(d, SvPVX(key), SvCUR(key)) % size, bits);
    if (AvFILL(ref) > 2) {
      SV **keys = AvARRAY((AV*)SvRV(AvARRAY(ref)[3]));
      RETVAL = (SvCUR(key) == SvCUR(keys[v]) && memEQ(SvPVX(keys[v]), SvPVX(key), SvCUR(key)))
        ? v : -1;
    } else {
      RETVAL = v;
    }
OUTPUT:
    RETVAL

UV
hash(buf, seed=0)
  SV* buf
  UV  seed;
CODE:
    if (items < 2) {
      if (SvPOK(buf))
        RETVAL = crc32(0, SvPVX(buf), SvCUR(buf));
      else
        RETVAL = crc32(0, NULL, 0);
    }
	else
	  RETVAL = crc32(seed, SvPVX(buf), SvCUR(buf));
OUTPUT:
    RETVAL
