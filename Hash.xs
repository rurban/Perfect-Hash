/* -*- tab-width:4 mode:c -*- */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef HAVE_ZLIB
#  include "zlib.h"
#  define HASHNAME "crc32_zlib"
#else
#  ifdef __SSE4_2__
#    define crc32(seed,str,len) crc32_sse42((seed),(str),(len))
#    define HASHNAME "crc32_sse42"
#  else
#    define crc32(seed,str,len) fnv_hash_len((seed),(str),(len))
#    define HASHNAME "fnv"
#  endif
#endif

#ifdef _MSC_VER
#define INLINE __inline
#else
#define INLINE inline
#endif

#if PERL_VERSION < 10
#  define USE_PPPORT_H
#endif

#ifdef USE_PPPORT_H
#  include "ppport.h"
#endif

#define CRCSTR(sv) (const unsigned char *)(SvPVX(sv))

/* FNV algorithm from http://isthe.com/chongo/tech/comp/fnv/ */
static INLINE
unsigned fnv_hash_len (unsigned d, const char *s, const int l) {
    int c = *s++;
    int i = 0;
    if (!d) d = 0x01000193;
    for (; i < l; i++) {
        d = ((d * 0x01000193) ^ *s++) & 0xffffffff;
    }
    return d;
}

#ifdef __SSE4_2__
#include <stdint.h>
#include <smmintrin.h>

/* Byte-boundary alignment issues */
#define ALIGN_SIZE      0x08UL
#define ALIGN_MASK      (ALIGN_SIZE - 1)
#define CALC_CRC(op, crc, type, buf, len)                               \
  do {                                                                  \
    for (; (len) >= sizeof (type); (len) -= sizeof(type), buf += sizeof (type)) { \
      (crc) = op((crc), *(type *) (buf));                               \
    }                                                                   \
  } while(0)


/* iSCSI CRC-32C using the Intel hardware instruction. */
/* for better parallelization with bigger buffers see
   http://www.drdobbs.com/parallel/fast-parallelized-crc-computation-using/229401411 */
static INLINE
unsigned int crc32_sse42(unsigned int crc, const char *buf, int len) {
    /* XOR the initial CRC with INT_MAX */
    crc ^= 0xFFFFFFFF;
    /* Align the input to the word boundary */
    for (; (len > 0) && ((size_t)buf & ALIGN_MASK); len--, buf++) {
        crc = _mm_crc32_u8(crc, *buf);
    }
#ifdef __x86_64__ /* or Aarch64... */
    CALC_CRC(_mm_crc32_u64, crc, uint64_t, buf, len);
#endif
    CALC_CRC(_mm_crc32_u32, crc, uint32_t, buf, len);
    CALC_CRC(_mm_crc32_u16, crc, uint16_t, buf, len);
    CALC_CRC(_mm_crc32_u8, crc, uint8_t, buf, len);
    return (crc ^ 0xFFFFFFFF);
}
#endif

/* #define VEC(G, index, bits) (IV)((*(IV*)(G + ((index) * bits/8))) & ((1<<bits)-1)) */

/* Urban TODO: return SV* and store SV's in values, not just indices.
   maybe check for indices optimization as stored now.
   use AV * V, not the 2nd half of SvPVX(G). */

static INLINE
IV vec(char *G, IV index, IV bits) {
  if (bits == 8)
    return *(char*)(G + index) & 255;
  else if (bits == 4)
    return *(char*)(G + (index / 2)) & 15;
  else if (bits == 16) {
    short l = *(short*)((short*)G + index) & 65535; /* __UINT16_MAX__ */
    return (IV)l;
  }
  else if (bits == 32) {
#if INTSIZE == 4
    int l = *(int*)((int*)G + index); /* __UINT32_MAX__ */
#else
    long l = *(long*)((long*)G + index); /* __UINT32_MAX__ */
#endif
    return (IV)l;
  }
#ifdef HAS_QUAD
  else if (bits == 64) {
    long long l = *(long long*)((long long*)G + index);
    return (IV)l;
  }
#endif
  die("Unsupported bits %"IVdf"\n", bits);
  return 0;
}

static char *
hashname() {
  return HASHNAME;
}


MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Hanov

PROTOTYPES: DISABLE

UV
hash(obj, key, seed=0)
  SV* obj
  SV* key
  UV  seed;
CODE:
    if (items < 3) {
      if (SvPOK(key))
        RETVAL = crc32(0, CRCSTR(key), SvCUR(key));
      else
        RETVAL = crc32(0, NULL, 0);
    }
	else
	  RETVAL = crc32(seed, CRCSTR(key), SvCUR(key));
OUTPUT:
    RETVAL

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
    UV h  = crc32(0, CRCSTR(key), SvCUR(key)) % size;
    IV d  = SvIVX(ga[h]);
    SV *v = d < 0
      ? va[-d-1]
      : d == 0
        ? va[h]
        : va[crc32(d, CRCSTR(key), SvCUR(key)) % size];
    if (AvFILL(ref) > 2) {
      SV **keys = AvARRAY((AV*)SvRV(AvARRAY(ref)[3]));
      IV iv = SvIVX(v);
      RETVAL = ( SvCUR(key) == SvCUR(keys[iv])
              && memEQ(SvPVX(keys[iv]), SvPVX(key), SvCUR(key)))
        ? SvREFCNT_inc_NN(v) : &PL_sv_undef;
    } else {
      RETVAL = SvREFCNT_inc_NN(v);
    }
OUTPUT:
    RETVAL

# TODO: allow setting the hashname via 2nd arg
# and store it in a global symbol

char *
hashname(obj)
  SV* obj
CODE:
    RETVAL = hashname();
OUTPUT:
    RETVAL

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Urban

PROTOTYPES: DISABLE

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
    char *V = G+(size * bits/8);
    unsigned long h = crc32(0, CRCSTR(key), SvCUR(key)) % size;
    IV d = vec(G, h, bits);
    IV v;
    if (bits == 32) {
      if (d >= 2147483647)
        d = (long)(d - 4294967295U);
    }
#ifdef HAVE_QUAD
    else if (bits == 64) {
      if (d >= 9223372036854775807ULL)
        d = (IV)((long long)(d - 18446744073709551615ULL));
    }
#endif
    else {
      if (d >= 1<<(bits-1))
        d = (d - (1<<bits));
    }
    v = d < 0
      ? vec(V, -d-1, bits)
      : d == 0 ? vec(V, h, bits)
               : vec(V, (UV)crc32(d, CRCSTR(key), SvCUR(key)) % size, bits);
#ifdef DEBUGGING
    if (hv_exists((HV*)SvRV(AvARRAY(ref)[2]), "-debug", 6)) {
      printf("\nxs: h0=%2lu d=%3ld v=%2ld\t", h,
             d>0 ? crc32(d,CRCSTR(key),SvCUR(key))%size : (long)d, (long)v);
    }
#endif
    if (AvFILL(ref) > 2) {
      AV *av = (AV*)SvRV(AvARRAY(ref)[3]);
      SV **keys = AvARRAY(av);
      if (v >= AvFILL(av)) {
#ifdef DEBUGGING
        assert(v < size);
#endif
        RETVAL = -1;
      }
      RETVAL = (SvCUR(key) == SvCUR(keys[v]) && memEQ(SvPVX(keys[v]), SvPVX(key), SvCUR(key)))
        ? v : -1;
    } else {
      RETVAL = v;
    }
OUTPUT:
    RETVAL

IV
nvecget(v, index, bits)
  SV* v
  IV  index
  IV  bits
CODE:
  char *V = SvPVX(v);
  RETVAL = vec(V, index, bits);
OUTPUT:
  RETVAL

void
nvecset(v, index, bits, value)
  SV* v
  IV  index
  IV  bits
  IV  value
CODE:
  char *V = SvPVX(v);
  if (bits == 8)
    *(char*)(V + index) = value & 255;
  else if (bits == 4) /* TODO: shift and mask ? */
    *(char*)(V + (index / 2)) = value & 15;
  else if (bits == 16)
    *(short*)((short*)V + index) = value & 65535;
  else if (bits == 32)
#if INTSIZE == 4
    *(int*)((int*)V + index) = value & 4294967295;
#else
    *(long*)((long*)V + index) = value & 4294967295;
#endif
#ifdef HAS_QUAD
  else if (bits == 64)
    *(long long*)((long long*)V + index) = (long long)value;
#endif

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Pearson

PROTOTYPES: DISABLE

UV
xs_hash(ph, key)
  SV* ph
  SV* key
CODE:
    AV *ref = (AV*)SvRV(ph);
    int size = SvIVX(AvARRAY(ref)[0]);
    AV *H = (AV*)SvRV(AvARRAY(ref)[1]);
    long d = 0;
    int hsize = AvFILL(H);
    register int i = 0;
    assert(SvTYPE(H) == SVt_PVAV);
    if (!SvPOK(key)) {
      XSRETURN_UV(0);
    }
    if (hsize == 256) {
      unsigned char *s = (unsigned char*)SvPVX(key);
      unsigned char h[256];
      for (; i < 256; i++) {
        h[i] = SvIVX(AvARRAY(H)[i]);
      }
      for (i=0; i < SvCUR(key); i++) {
        d = h[ d ^ *s++ ];
      }
    }
    else {
      unsigned char *s = (unsigned char*)SvPVX(key);
      for (; i < SvCUR(key); i++) {
        d = SvIVX(AvARRAY(H)[(d ^ *s++) % hsize]);
      }
    }
    RETVAL = d % size;
OUTPUT:
    RETVAL

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Pearson16

PROTOTYPES: DISABLE

UV
hash(ph, key)
  SV* ph
  SV* key
CODE:
    AV *ref = (AV*)SvRV(ph);
    int size = SvIVX(AvARRAY(ref)[0]);
    AV *H = (AV*)SvRV(AvARRAY(ref)[1]);
    unsigned char *s = (unsigned char*)SvPVX(key);
    const int len = SvCUR(key);
    register int i;
    register unsigned short d = 0;
    if (!SvPOK(key) || !SvCUR(key)) {
      XSRETURN_UV(0);
    }
    for (i = 0; i < (len % 2 ? len -1 : len); i++) {
      d = SvIVX(AvARRAY(H)[ (unsigned short)(d ^ *(unsigned short*)s++) ]);
    }
    if (len % 2)
      d = SvIVX(AvARRAY(H)[ (unsigned short)(d ^ SvPVX(key)[len-1]) ]);
    RETVAL = d % size;
OUTPUT:
    RETVAL

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Pearson32

PROTOTYPES: DISABLE

UV
hash(ph, key)
  SV* ph
  SV* key
CODE:
    AV *ref = (AV*)SvRV(ph);
    int size = SvIVX(AvARRAY(ref)[0]);
    AV *H = (AV*)SvRV(AvARRAY(ref)[1]);
    unsigned char *s = (unsigned char*)SvPVX(key);
    const int len = SvCUR(key);
    unsigned char h[256];
    unsigned int *hi = (unsigned int *)h;
    int limit;
    register int i = 0;
    register long d = 0;
    if (!SvPOK(key) || !SvCUR(key)) {
      XSRETURN_UV(0);
    }
    for (; i < 256; i++) {
      h[i] = SvIVX(AvARRAY(H)[i]);
    }
    for (i=0; i < len/4; i += 4, s += 4) {
      d = hi[ ((unsigned int)d ^ *(unsigned int*)s) % 64 ];
    }
    for (; i < len; i++, s++) {
      d = h[ (unsigned char)((d % 256) ^ *s) ];
    }
    RETVAL = d % size;
OUTPUT:
    RETVAL
