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

MODULE = Perfect::Hash::CMPH	PACKAGE = Perfect::Hash::CMPH

SV*
_new(class, dict, ...)
    SV*  class
    SV*  dict
  CODE:
  {
    FILE * keys_fd = NULL;
    cmph_io_adapter_t *key_source;
    cmph_config_t *mph;
    double c;
	cmph_t *mphf;
    CMPH_ALGO algo = CMPH_CHM;
    const char *classname = SvPVX(class);

    if (SvTYPE(dict) == SVt_PV) {
      keys_fd = fopen(SvPVX(dict), "r");
      key_source = cmph_io_nlfile_adapter(keys_fd);
    } else {
      keys_fd = fopen("examples/words1000", "r");
      key_source = cmph_io_nlfile_adapter(keys_fd);
    }
    /* const char *cmph_names[] = {"bmz", "bmz8", "chm", "brz", "fch", "bdz", "bdz_ph", "chd_ph", "chd", NULL };*/
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

    RETVAL = sv_bless(newRV(newSViv(PTR2IV(mphf))), gv_stashpv(classname, GV_ADDWARN));
  }
OUTPUT:
    RETVAL

IV
perfecthash(ph, key)
    SV*  ph
    SV*  key
CODE:
    SV *ref = SvRV(ph);
    cmph_t *mphf = (cmph_t *)SvIVX(ref);
    RETVAL = cmph_search(mphf, SvPVX(key), SvCUR(key));
OUTPUT:
    RETVAL
