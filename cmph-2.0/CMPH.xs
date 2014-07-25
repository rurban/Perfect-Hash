/* -*- mode:C tab-width:4 -*- */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "cmph.h"

#ifdef USE_PPPORT_H
#  define NEED_sv_2pvbyte
#  define NEED_sv_2pv_nolen
#  define NEED_sv_pvn_force_flags
#  include "ppport.h"
#endif

MODULE = Perfect::Hash::CMPH	PACKAGE = Perfect::Hash::CMPH::CHM

SV*
new(class, dict, ...)
    SV*  class
    SV*  dict
CODE:
    RETVAL = &PL_sv_undef;
OUTPUT:
    RETVAL

IV
perfecthash(ph, key)
    SV*  ph
    SV*  key
CODE:
    RETVAL = -1;
OUTPUT:
    RETVAL
