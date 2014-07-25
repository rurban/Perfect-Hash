use strict;
#use 5.005062;
use ExtUtils::MakeMaker;

WriteMakefile
  (
   'NAME'	   => 'Perfect::Hash',
   'VERSION_FROM'  => 'lib/Perfect/Hash.pm',
   'ABSTRACT_FROM' => 'lib/Perfect/Hash.pm',
   'PREREQ_PM'	=> {
     'coretypes' => 0,
   },
   AUTHOR        => 'Reini Urban',
   ($ExtUtils::MakeMaker::VERSION gt '6.46' ?
    ('META_MERGE'  =>
     {
      resources =>
      {
       repository  => 'http://github.com/rurban/Perfect-Hash',
       license     => 'http://dev.perl.org/licenses/',
      },
     }
    ) : ()),
    SIGN => 1
  );


package MY;
use Config;

sub dist {
  local $_ = shift->SUPER::dist(@_);
  s/DIST_DEFAULT = /DIST_DEFAULT = README.md /;
  return $_;
}

sub depend {
  "
README.md : \$(VERSION_FROM)
	pod2markdown \$(VERSION_FROM) > \$@

release : dist
	git commit -a -m\"release \$(VERSION)\"
	git tag \$(VERSION)
	cpan-upload \$(DISTVNAME).tar\$(SUFFIX)
	git push
	git push --tags
test_cover :: pure_all
	$(RM_RF) cover_db
	$(PERLRUNINST) -S cover -test
test_coveralls :: pure_all
	$(PERLRUNINST) -S cover -test -report coveralls
"
}