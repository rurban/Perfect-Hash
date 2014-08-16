/* -*- mode:C tab-width:4 -*- */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "cmph.h"

#if PERL_VERSION < 10
#  define USE_PPPORT_H
#endif

#ifdef USE_PPPORT_H
#  include "../ppport.h"
#endif

MODULE = Perfect::Hash::CMPH	PACKAGE = Perfect::Hash::CMPH

SV*
_new(class, keyfile, ...)
    SV*  class
    SV*  keyfile
  CODE:
  {
    int i;
    UV size;
    AV *result;
    HV *options;
    FILE * keys_fd = NULL;
    cmph_io_adapter_t *key_source;
    cmph_config_t *mph;
    cmph_t *mphf;
    unsigned char *packed;
    CMPH_ALGO algo = CMPH_CHM;
    const char *classname = SvPVX(class);

    if (SvPOK(keyfile)) {
      keys_fd = fopen(SvPVX(keyfile), "r");
      key_source = cmph_io_nlfile_adapter(keys_fd);
    } else {
      if (SvTYPE(keyfile) == SVt_PVAV) {
      } else if (SvTYPE(keyfile) == SVt_PVHV) {
      }
      /* XXX support arrayrefs at least, probably created via nvecset
         and use the io_vector or io_byte_vector adapter */
      warn("CMPH only accepts filenames yet\n");
      /*keys_fd = fopen("examples/words500", "r");
        key_source = cmph_io_nlfile_adapter(keys_fd);*/
      XSRETURN_UNDEF;
    }
    if (!strcmp(classname, "Perfect::Hash::CMPH::CHM"))         algo = CMPH_CHM;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::BMZ"))    algo = CMPH_BMZ;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::BMZ8"))   algo = CMPH_BMZ8;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::BRZ"))    algo = CMPH_BRZ;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::FCH"))    algo = CMPH_FCH;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::BDZ"))    algo = CMPH_BDZ;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::BDZ_PH")) algo = CMPH_BDZ_PH;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::CHD"))    algo = CMPH_CHD;
    else if (!strcmp(classname, "Perfect::Hash::CMPH::CHD_PH")) algo = CMPH_CHD_PH;
    mph = cmph_config_new(key_source);
    if (algo != CMPH_CHM)
      cmph_config_set_algo(mph, algo);
    mphf = cmph_new(mph);
    if (!mphf) {
      fprintf(stderr, "Failed to create mphf for algorithm %s", classname);
      XSRETURN_UNDEF;
    }
    result = newAV();
    av_push(result, newSViv(PTR2IV(mphf)));                  /* mphf in [0] */
    size = cmph_packed_size(mphf);
    packed = (char *)malloc(size);
    cmph_pack(mphf, packed);
    av_push(result, newSVpvn(packed, size+1));             /* packed in [1] */
    options = newHV();
    for (i=2; i<items; i++) { /* CHECKME */
      hv_store_ent(options, ST(i), newSViv(1), 0);
    }
    av_push(result, newRV((SV*)options));                 /* options at [2] */
    RETVAL = sv_bless(newRV_noinc((SV*)result), gv_stashpv(classname, GV_ADDWARN));
  }
OUTPUT:
    RETVAL

IV
perfecthash(ph, key)
    SV*  ph
    SV*  key
CODE:
    AV *ref = (AV*)SvRV(ph);
    cmph_t *mphf = (cmph_t *)SvIVX(AvARRAY(ref)[0]);
    if (!mphf) die ("Empty cmph");
    RETVAL = cmph_search(mphf, SvPVX(key), SvCUR(key));
OUTPUT:
    RETVAL
