/* -*- mode:C tab-width:4 -*- */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "zlib.h"

#ifdef USE_PPPORT_H
#  define NEED_sv_2pvbyte
#  define NEED_sv_2pv_nolen
#  define NEED_sv_pvn_force_flags
#  include "ppport.h"
#endif

MODULE = Perfect::Hash	PACKAGE = Perfect::Hash::Urban

unsigned long
hash(buf, seed=0)
  SV*   buf
  unsigned long seed;
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
