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
_new(class, dict, ...)
    SV*  class
    SV*  dict
  CODE:
  {
    int i;
    AV *result;
    HV *options;
    FILE * keys_fd = NULL;
    cmph_io_adapter_t *key_source;
    cmph_config_t *mph;
    cmph_t *mphf;
    FILE *dump_fd;
    char *dump_fname;
    CMPH_ALGO algo = CMPH_CHM;
    const char *classname = SvPVX(class);

    if (SvTYPE(dict) == SVt_PV) {
      keys_fd = fopen(SvPVX(dict), "r");
      key_source = cmph_io_nlfile_adapter(keys_fd);
    } else {
      /* XXX support arrayrefs at least, probably created via nvecset
         and use the io_vector or io_byte_vector adapter */
      keys_fd = fopen("examples/words500", "r");
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

    result = newAV();
    av_push(result, newSViv(PTR2IV(mphf))); /* [0] */

    dump_fname = "cmph_dump.tmp";
    options = newHV();
    for (i=2; i<items; i++) { /* CHECKME */
      hv_store_ent(options, ST(i), newSViv(1), 0);
      if (strEQ(SvPVX(ST(i)), "dump")) {
        dump_fname = SvPVX(ST(++i));
      }
    }
    av_push(result, newRV((SV*)options));  /* [1] */

    dump_fd = fopen(dump_fname, "w");
    cmph_dump(mphf, dump_fd);
    fclose(dump_fd);

    av_push(result, newSVpvn(dump_fname, strlen(dump_fname)));  /* [2] */
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
    RETVAL = cmph_search(mphf, SvPVX(key), SvCUR(key));
OUTPUT:
    RETVAL
