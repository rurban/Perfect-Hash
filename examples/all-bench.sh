#/bin/sh
p=perl5.20.0-nt

make clean
$p Makefile.PL && make -s
cd bob; git checkout Makefile; cd ..
g=`git describe --long --tags --dirty --always`

$p -Mblib examples/bench.pl -size 127 -nul         | tee log.bench-$g-127
$p -Mblib examples/bench.pl -size 500 -nul         | tee log.bench-$g-500
$p -Mblib examples/bench.pl -size 2000 -nul -1opt  | tee log.bench-$g-2000
$p -Mblib examples/bench.pl -size 10000 -nul -1opt | tee log.bench-$g-10000
$p -Mblib examples/bench.pl -size 25000 -nul -1opt | tee log.bench-$g-25000
$p -Mblib examples/bench.pl                        | tee log.bench-$g
