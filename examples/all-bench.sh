#/bin/sh
p=${p:-perl}

make clean
$p Makefile.PL && make -s
#cd bob; git checkout Makefile; cd ..
g=`git describe --long --tags --dirty --always`

$p -Mblib examples/bench.pl -size 127              | tee log.bench-$g-127
$p -Mblib examples/bench.pl -size 500              | tee log.bench-$g-500
$p -Mblib examples/bench.pl -size 2000             | tee log.bench-$g-2000
$p -Mblib examples/bench.pl -size 10000 -nul -1opt | tee log.bench-$g-10000
$p -Mblib examples/bench.pl -size 25000 -nul -1opt | tee log.bench-$g-25000
$p -Mblib examples/bench.pl -nul -pic -1opt        | tee log.bench-$g
