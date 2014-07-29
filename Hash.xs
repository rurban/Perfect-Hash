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

SV*
perfecthash(ph, key)
  SV* ph
  SV* key;
CODE:
    AV *ref = (AV*)SvRV(ph);
    AV *g = (AV*)SvRV(AvARRAY(ref)[0]);
    SV **ga = AvARRAY(g);
    UV size = AvFILL(g);
    SV **va = AvARRAY((AV*)SvRV(AvARRAY(ref)[1]));
    IV d = SvIVX(ga[ crc32(0, SvPVX(key), SvCUR(key)) % size]);
    SV *v = d < 0 ? va[-d-1] : va[ crc32(d, SvPVX(key), SvCUR(key)) % size];
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
