# library of Perfect::Hash test functions

use strict;
use Config;
use ExtUtils::Embed qw(ccflags ldopts);
use B ();

# usage: my ($default, $methods, $opts) = opt_parse_args(@default_opts);
sub test_parse_args {
  opt_parse_args(@_);
}

sub opt_parse_args {
  my @opts = @_;
  my @methods = map {s/::/-/g; lc $_} @Perfect::Hash::algos;
  my $default;
  if (@ARGV and grep /^-/, @ARGV) {
    my @m = ();
    for (@ARGV) {
      my ($m) = /^-(.*)/;
      if (defined($m) and exists $Perfect::Hash::algo_methods{$m}) {
        push @m, $_;
      } else {
        push @opts, $_;
      }
    }
    @methods = @m ? @m : ('', map {"-".$_} @methods);
  } else {
    $default = 1;
    @methods = ('', map {"-".$_} @methods);
  }
  return ($default, \@methods, \@opts);
}

# my ($dict, $dictarr, $size, $custom_size) = opt_dict_size($opts, "examples/utf8");
# my @dict = @$dictarr;
sub opt_dict_size {
  my $opts = $_[0];
  my $dict = $_[1] || "examples/words";

  my ($size, $custom_size, @dict);
  if (!grep /^-dict$/, @$opts) {
    open my $d, "<", $dict or die "$dict not found. $!"; {
      local $/;
      @dict = split /\n/, <$d>;
    }
    close $d;
    $size = scalar @dict;
  } else {
    for (0..scalar(@$opts)-1) {
      if ($opts->[$_] eq '-dict') {
        $dict = $opts->[$_ + 1];
        open my $d, "<", $dict or die "$dict not found. $!"; {
          local $/;
          @dict = split /\n/, <$d>;
        }
        close $d;
        $size = scalar @dict;
        splice(@$opts, $_, 2);
        last;
      }
    }
  }

  if (grep /^-size$/, @$opts) {
    for (0..scalar(@$opts)-1) {
      if ($opts->[$_] eq '-size') {
        my $s = $opts->[$_ + 1];
        if ($s > 2 and $s <= $#dict) {
          $#dict = $s - 1;
          $size = scalar @dict;
          $custom_size++;
        } else {
          warn "Invalid -size $size\n";
        }
        splice(@$opts, $_, 2);
        last;
      }
    }
  }
  return ($dict, \@dict, $size, $custom_size);
}

sub compile_shared {
  my $ph = shift;
  my $suffix = shift || "";
  my $opt = $Config{optimize};
  $opt =~ s/-O[xs12]/-O3/;
  my $dlext = ".".$Config{dlext};
  my $cmd = $Config{cc}." -shared ".$ph->c_include()." -I. $opt ".ccflags
           ." ".$Config{cccdlflags}
           ." -o phash$suffix$dlext phash$suffix.c";
  #if ($^O eq 'MSWin32' and $Config{cc} =~ /cl/) {
  #  $cmd =~ s/-o phash$suffix$dlext/-nologo -Fo phash$suffix.dll/;
  #}
  return $cmd;
}

sub link_shared {
  my $ph = shift;
  my $suffix = shift || "";
  my $opt = $Config{optimize};
  $opt =~ s/-O[xs12]/-O3/;
  my $dlext = ".".$Config{dlext};
  my $cmd = $Config{cc}.$ph->c_include()." -I. $opt ".ccflags
           ." ".$Config{cccdlflags}
           ." -o phash$suffix main$suffix.c phash$suffix$dlext ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  if ($^O eq 'MSWin32' and $Config{cc} =~ /cl/) {
    $cmd =~ s/-o phash$suffix/-nologo -Fe phash$suffix.exe/;
  }
  $cmd .= $ph->c_lib();
  return $cmd;
}


sub compile_static {
  my $ph = shift;
  my $suffix = shift || "";
  my $opt = $Config{optimize};
  $opt =~ s/-O[xs12]/-O3/;
  my $cmd = $Config{cc}.$ph->c_include()." -I. $opt ".ccflags
           ." -o phash$suffix main$suffix.c phash$suffix.c ".ldopts;
  chomp $cmd; # oh yes! ldopts contains an ending \n
  if ($^O eq 'MSWin32' and $Config{cc} =~ /cl/) {
    $cmd =~ s/-o phash$suffix/-nologo -Fe phash$suffix.exe/;
  }
  $cmd .= $ph->c_lib();
  return $cmd;
}

sub test_wmain {
  my ($m, $fp, $key, $value, $suffix, $nul) = @_;
  use bytes;
  $value = 0 unless $value;
  $suffix = "" unless $suffix;
  my ($decl, $result, $post_lookup) = ('','v','');
  if ($m eq "-gperf") {
    $decl = "struct phash_table *res;";
    $result = "res";
    $post_lookup = "v = res ? res->value : -1;";
    $nul = 1;
  }
  my $FH;
  # and then we need a main also
  open $FH, ">", "main$suffix.c";
  print $FH "
#include <stdio.h>
#include \"phash$suffix.h\"

int main () {
  long v;
  int err = 0;
  $decl
  $result = phash$suffix\_lookup(", B::cstring($key) . ($nul ? ', '.length($key) : "") . ");
  $post_lookup
  if (v == $value) {
    printf(\"ok - c lookup exists %ld\\n\", v);
  } else {
    printf(\"not ok - c lookup exists %ld\\n\", v); err++;
  }";
  unless ($fp) {
    print $FH "
  return err;
}
";
    close $FH;
    return;
  }
  print $FH "
  $result = phash$suffix\_lookup(\"notexist\"" . ($nul ? ", 8" : "") . ");
  $post_lookup
  if (v == -1) {
    printf(\"ok - c lookup notexists %ld\\n\", v);
  } else {
    printf(\"not ok - c lookup notexists %ld\\n\", v); err++;
  }
  return err;
}
";
  close $FH;
}

sub test_wmain_all {
  my ($m, $keys, $opts, $suffix) = @_;
  use bytes;
  $suffix = "" unless $suffix;
  my ($decl, $result, $post_lookup) = ('','v','');
  $opts = join(" ", @$opts) if ref $opts eq 'ARRAY';
  my ($nul) = $opts =~ /-nul/;
  if ($m eq "-gperf") {
    $decl = "struct phash_table *res;";
    $result = "res";
    $post_lookup = "
    v = res ? res->value : -1;";
    $nul = 1;
  }
  my $FH;
  # and then we need a main also
  open $FH, ">", "main$suffix.c";
  print $FH '#include <string.h>';
  print $FH "
#include <stdio.h>
#include \"phash$suffix.h\"

static const char *testkeys[] = {
  ";
  my $size = int(scalar(@$keys));
  for my $i (0..$size) {
    print $FH B::cstring($keys->[$i]),", ";
    print $FH "\n  " unless $i % 8;
  }
  print $FH "
};

int main () {
  long v;
  int i;
  int err = 0;
  $decl
  for (i=0; i < $size; i++) {
    $result = phash$suffix\_lookup(testkeys[i]",
                $nul ? ', strlen(testkeys[i]));' : ');';
  # skip the last key if empty
  print $FH $post_lookup;
  if ($opts =~ /-debug-c/) {
      print $FH '
    if (i != v) {
      if (i == ',$size-1,' && (testkeys[i]==NULL || !strlen(testkeys[i]))) continue;
      if (v>=0) err++;
      printf("%d: %s[%d]=>%ld\n", err, testkeys[i], i, v);
    }';
    } else {
      print $FH '
    if (i != v) {
      if (i == ',$size-1,' && (testkeys[i]==NULL || !strlen(testkeys[i]))) continue;
      printf("not ok - c lookup %s at %d => %ld\n", testkeys[i], i, v); err++;
    }';
  }
  print $FH "
  }
  return err;
}
";
  close $FH;
  return;
}

1;
