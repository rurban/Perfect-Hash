add-auto-load-safe-path /lib/x86_64-linux-gnu/libthread_db-1.0.so

define sdump
  p/x *$arg0
  call Perl_sv_dump($arg0)
end
document sdump
sdump sv => p/x *sv; Perl_sv_dump(sv)
see `help tsdump`
end
