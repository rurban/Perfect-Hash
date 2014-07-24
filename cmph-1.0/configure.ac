dnl Process this file with autoconf to produce a configure script.
AC_INIT(Makefile.am)
AM_INIT_AUTOMAKE(cmph, 1.0)
AM_CONFIG_HEADER(config.h)
AC_CONFIG_MACRO_DIR([m4])

dnl Checks for programs.
AC_PROG_AWK
AC_PROG_CC
AC_PROG_CXX
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_LIBTOOL
AC_SYS_EXTRA_LARGEFILE
if test "x$ac_cv_sys_largefile_CFLAGS" = "xno" ; then
	ac_cv_sys_largefile_CFLAGS=""
fi
if test "x$ac_cv_sys_largefile_LDFLAGS" = "xno" ; then
	ac_cv_sys_largefile_LDFLAGS=""
fi
if test "x$ac_cv_sys_largefile_LIBS" = "xno" ; then
	ac_cv_sys_largefile_LIBS=""
fi
CFLAGS="$CFLAGS $ac_cv_sys_largefile_CFLAGS"
LDFLAGS="$LDFLAGS $ac_cv_sys_largefile_LDFLAGS"
LIBS="$LIBS $ac_cv_sys_largefile_LIBS"


dnl Checks for headers
AC_CHECK_HEADERS([getopt.h math.h])

dnl Checks for libraries.
AC_CHECK_LIBM  
LDFLAGS="$LIBM $LDFLAGS"

dnl Checks for library functions.

AC_CHECK_SPOON
dnl AC_OUTPUT(Makefile tests/Makefile samples/Makefile)
AC_OUTPUT(Makefile src/Makefile tests/Makefile examples/Makefile man/Makefile cmph.pc)
