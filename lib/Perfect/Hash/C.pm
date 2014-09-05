package Perfect::Hash::C;
use strict;
our $VERSION = '0.01';
our @ISA = qw(Perfect::Hash Exporter);

use Exporter 'import';
our @EXPORT = qw(memcmp_const_str _save_c_array c_stringpool u_csize s_csize);
use B ();
use Config;

=head1 NAME

Perfect::Hash::C - generate C code for perfect hashes

=head1 SYNOPSIS

    use Perfect::Hash;

    $hash->{chr($_)} = int rand(2) for 48..90;
    my $ph = new Perfect:Hash $hash, -for-c;
    $ph->save_c("ph"); # => ph.c, ph.h

    Perfect::Hash->new([split/\n/,`cat /usr/share/dict/words`])->save_c;
    # => phash.c, phash.h

=head1 DESCRIPTION

There exist various C or python libraries to generate code to access
perfect hashes and minimal versions thereof, but none are satisfying.
The various libraries need to be hand-picked to special input data and
to special output needs. E.g. for fast lookup vs small memory footprint,
static vs shared C library, optimized for PIC. Size of the hash, 
type of the hash: only indexed (not storing the values), with C values
or with typed values. (Perl XS, C++, strings vs numbers, ...)

=head1 METHODS

=over


=item c_lib c_include

Returns a string with the required include path and libs to link to.

=cut

sub c_include { "" }

sub c_lib { "" }

=item save_h_header fileprefix, options

=item save_c_header fileprefix, options

=item c_funcdecl ph, FH

Helper methods for save_c

=cut

sub save_h_header {
  # refer to the class save_c method
  my $ph = shift;
  if (ref $ph eq __PACKAGE__ or ref $ph eq 'Perfect::Hash::C') {
    die "wrong class: ",ref $ph;
  }
  my $fileprefix = shift || "phash";
  my $base = $fileprefix;
  if ($fileprefix ne "phash") {
    require File::Basename;
    $base = File::Basename::basename $fileprefix;
  }
  my $FH;
  open $FH, ">", $fileprefix.".h" or die "$fileprefix.h: @!";
  print $FH $ph->c_funcdecl($base).";\n";
  close $FH;
  return ($fileprefix, $base);
}

sub save_c_header {
  my ($ph, $fileprefix, $base) = @_;
  my $FH;
  open $FH, ">", $fileprefix.".c" or die "$fileprefix.c: @!";
  print $FH "#include \"$base.h\"\n";
  print $FH "#include <string.h>\n"; # for memcmp/strlen
  return $FH;
}

sub c_funcdecl {
  my ($ph, $base) = @_;
  if ($ph->option('-nul')) {
    "
long $base\_lookup(const unsigned char* s, int l)";
  } else {
    "
long $base\_lookup(const unsigned char* s)";
  }
}

=back

=head1 FUNCTIONS

=over

=item _save_c_array ident FH, array, fmt

Internal helper method for save_c

=cut

sub _save_c_array {
  my ($ident, $FH, $G, $fmt) = @_;
  $fmt = "%3d" unless $fmt;
  my $size = scalar @$G;
  my $last = $size - 1;
  for (0 .. int($size / 16)) {
    my $from = $_ * 16;
    my $to = $from + 15;
    $to = $last if $to > $last;
    print $FH " " x $ident;
    for ($from .. $to) {
      my $g = $G->[$_];
      if ($fmt eq '"%s"') {
        printf $FH "%s,", B::cstring($g);
      } else {
        printf $FH $fmt.",", $g;
      }
    }
    print $FH "\n" if $ident;
  }
}

=item c_stringpool FH, array

Dump the strings as continous direct buffer.
Used by C<-pic>, as in C<gperf --pic>.

Sort the strings by length, properly aligned words first.

TODO: support holes in @G as in gperf

=cut

sub c_stringpool {
  my ($FH, $G) = @_;
  my $last = scalar @$G - 1;
  # sort by length, favor word-aligned strings first.
  # but this sort-order is only used internally of course. the keys itselves from 0..last
  my (@L, %L);
  printf $FH "
    /* sorted by aligned length */
    struct stringpool_t {";
  my $j = 0;
  my @S = sort {bytes::length($G->[$a]) <=> bytes::length($G->[$b])} (0 .. $last);
  for my $l (15, 7, 3) {
    for my $i (0 .. $last) {
      my $g = $G->[$i];
      if ($l == bytes::length($g)) {
        printf $FH "
      char stringpool_str%d[sizeof(%s)];", $i, B::cstring($g);
        $L[$j] = $i;
        $L{$i} = $j;
        $j++;
      }
    }
  }
  for my $i (@S) {
    my $g = $G->[$i];
    printf $FH "
      char stringpool_str%d[sizeof(%s)];", $i, B::cstring($g) unless exists $L{$i};
  }
  printf $FH "
    };
    static const struct stringpool_t stringpool_contents = {";
  for my $j (@L) {
    my $g = $G->[$j];
    printf $FH "
      %s, /* %d (length %d) */", B::cstring($g), $j, bytes::length($g) + 1;
  }
  for my $i (@S) {
    my $g = $G->[$i];
    printf $FH "
      %s, /* %d */", B::cstring($g), $i unless exists $L{$i};
  }
  printf $FH "
    };
    #define stringpool ((const char *) &stringpool_contents)
    static const int keys[] = {";
  # but this must be sorted in natural order
  for my $i (0..$last) {
    my $g = $G->[$i];
    printf $FH "
      (int)(long)&((struct stringpool_t *)0)->stringpool_str%i,", $i;
  }
  printf $FH "
    };";
}

=item utf8_valid bytes

Wouldn't it be nice if perl5 core would provide a utf8::valid function?
Well, it does but returns true for all bytes without the utf8 flag set.
We split those bytes inside utf8 sequences so the editor displays false
mojibake encodings.

=cut

sub utf8_valid {
  return shift =~
   /^( ([\x00-\x7F])              # 1-byte pattern
      |([\xC2-\xDF][\x80-\xBF])   # 2-byte pattern
      |((([\xE0][\xA0-\xBF])|([\xED][\x80-\x9F])
        |([\xE1-\xEC\xEE-\xEF][\x80-\xBF]))([\x80-\xBF]))  # 3-byte pattern
      |((([\xF0][\x90-\xBF])|([\xF1-\xF3][\x80-\xBF])
        |([\xF4][\x80-\x8F]))([\x80-\xBF]{2}))             # 4-byte pattern
  )*$ /x;
}

=item memcmp_const_str($string, $length, $value, $last_statement)

Returns a string for a faster memcmp replacement of dynamic C<s> with
static $string with optimized word-size comparisons, when we know the
length and one string in advance.

if last:
  "return $cmp ? $v : -1;"
else: (allowing falltrough)
  "if ($cmp) return $v;";

Returns if the last statement if C<$last>, otherwise as fallthrough to the next statement.
If $last_statement is true, returns -1 if not found, else $value.
C<$cmp> is constructed by repeated calls to C<_strcmp_i()>.

Examples:
    memcmp_const_str("ACTH's", 6, 6)
  =>
     if (*(int*)s == (int)0x48544341 /* ACTH's */
	&& *(short*)&s[4] == (short)0x7327 /* 's */) return 6;

    memcmp_const_str("Americanization", 15, 546, 1)
  =>
    return *(unsigned long *)s == (unsigned long)0x6e61636972656d41ULL /* Americanization */
		&& *(int*)&s[8] == (int)0x74617a69 /* ization */
		&& *(short*)&s[12] == (short)0x6f69 /* ion */
		&& *(&s[14]) == 'n' ? 546 : -1;

Do away with most memcmp for shorter strings. cutoff 36 (TODO: try higher cutoffs, 128)
TODO: might need to check run-time char* alignment on non-intel platforms

  memcmp vs wordsize cmp via _strcmp_i(): (slow mac air)
  switch       0.005779  0.002551 0.307492   352346    35152  -1opt (2000)
            => 0.004587  0.004156 0.553640  1038117    51536  -1opt
  switch       0.006598  0.003342 0.165452    15018    22864  -1opt (127)
            => 0.004707  0.001989 0.171876    21062    22840
=cut

sub memcmp_const_str {
  my ($s, $l, $v, $last) = @_;
  my $cmp;
  if ($l == 0) {
    $cmp = "0"; # empty string is false, this key does not exist (added by ourself most likely)
  } elsif ($l > 36) { # cutoff 36 for short words, not using memcmp.
    $cmp = strcmp_str("s", $s, $l);
  } else {
    my ($n, $ptr) = (1, "s");
    $cmp = "";
    my $i = 0;
    while ($l >= 1) {
      if ($l >= 16) {
        $n = 16;
      } elsif ($l >= 8) {
        $n = 8;
      } elsif ($l >= 4) {
        $n = 4;
      } elsif ($l >= 2) {
        $n = 2;
      } else {
        $n = 1;
      }
      $cmp = "$cmp\n\t\t&& ".strcmp_str($ptr, $s, $n);
      $l -= $n;
      if ($l >= 1) {
        $i += $n;
        $s = bytes::substr($s, $n);
        $ptr = "&s[$i]";
      }
    }
    $cmp = substr($cmp, 6);
  }
  if ($last) {
    return "return $cmp ? $v : -1;";
  } else {
    return "if ($cmp) return $v;";
  }
}

=item strcmp_str($ptr, $s, $l)

Inner helper function to return a length optimized memcmp.

E.g. returns for a $s of length $l 4 at s[4]:

    *(int*)&s[4] == (int)0x73274941 /* AI's */)

Used by C<memcmp_const_str> to C<&&> together fast word-sized
comparisons of buffers.

=cut

sub strcmp_str {
  my ($ptr, $s, $l) = @_;
  # $s via byte::substr might be a non-conforming utf8 part (split in the middle).
  # if so what should we do? only used for comments, but it screws up emacs or
  # other strict encoding detectors. and no, utf8::valid does not work, because
  # it always returns true when the utf8 flag is off
  my $cs = utf8_valid($s)
    ? $s
    : B::cstring($s);
  if ($l == 16 and $Config{d_quad} and $Config{longlongsize} == 16) { # 128-bit qword
    my $quad = sprintf("0x%llx", unpack("Q", $s));
    my $quadtype = $Config{uquadtype};
    return "*($quadtype *)$ptr == ($quadtype)$quad"."ULL /* $cs */";
  } elsif ($l == 8 and $Config{d_quad} and $Config{longlongsize} == 8) {
    my $quad = sprintf("0x%lx", unpack("Q", $s));
    my $quadtype = $Config{uquadtype};
    return "*($quadtype *)$ptr == ($quadtype)$quad"."ULL /* $cs */";
  } elsif ($l == 8 and $Config{longsize} == 8) {
    my $long = sprintf("0x%lx", unpack("J", $s));
    return "*(long *)$ptr == (long)$long /* $cs */";
  } elsif ($Config{intsize} == 4 and $l == 4) {
    my $int = sprintf("0x%x", unpack("L", $s));
    return "*(int*)$ptr == (int)$int /* $cs */";
  } elsif ($l == 2) {
    my $short = sprintf("0x%x", unpack("S", $s));
    return "*(short*)$ptr == (short)$short /* $cs */";
  } elsif ($l == 1) {
    my $ord = ord($s);
    if ($ord >= 40 and $ord < 127) {
      return "*($ptr) == '$s'";
    } else {
      return "*($ptr) == $ord";
    }
  } else {
    return "!memcmp($ptr, ".B::cstring($s).", $l)";
  }
}

=item memcmp_const_len($symbol, $length, $value, $last_statement)

Returns a string for a faster memcmp replacement of dynamic C symbol C<s>
with the dynamic dynamic C symbol $symbol and constant length with optimized
word-size comparisons, when we know the length in advance.
C<$symbol> must be a scalar variable, not an index into an array or struct.

if last:
  "return $cmp ? $v : -1;"
else: (allowing falltrough)
  "if ($cmp) return $v;";

I<untested and yet unused>

=cut

sub memcmp_const_len {
  my ($s, $l, $v, $last) = @_;
  my $cmp;
  if ($l == 0) {
    $cmp = "0"; # empty string is false, this key does not exist (added by ourself most likely)
  } elsif ($l > 36) { # cutoff 36 for short words, not using memcmp.
    $cmp = strcmp_len("s", $s, $l);
  } else {
    my ($n, $ptr) = (1, "s");
    $cmp = "";
    my $i = 0;
    while ($l >= 1) {
      if ($l >= 16) {
        $n = 16;
      } elsif ($l >= 8) {
        $n = 8;
      } elsif ($l >= 4) {
        $n = 4;
      } elsif ($l >= 2) {
        $n = 2;
      } else {
        $n = 1;
      }
      $cmp = "$cmp\n\t\t&& ".strcmp_len($ptr, $s, $n);
      $l -= $n;
      if ($l >= 1) {
        $i += $n;
        $s = "&".$s."[$i]";
        $ptr = "&s[$i]";
      }
    }
    $cmp = substr($cmp, 6);
  }
  if ($last) {
    return "return $cmp ? $v : -1;";
  } else {
    return "if ($cmp) return $v;";
  }
}

# variant of strcmp_i with unknown 2nd string, only known length
# I<untested and yet unused>
sub strcmp_len {
  my ($ptr, $s, $l) = @_;
  if ($Config{d_quad} and $Config{longlongsize} == $l) { # 128-bit qword
    my $quadtype = $Config{uquadtype};
    return "*($quadtype *)$ptr == *($quadtype)$s";
  } elsif ($l == 8 and $Config{longsize} == 8) {
    return "*(long *)$ptr == *(long*)$s";
  } elsif ($l == 4 and $Config{intsize} == 4) {
    return "*(int*)$ptr == *(int*)$s";
  } elsif ($l == 2) {
    return "*(short*)$ptr == *(short*)$s";
  } elsif ($l == 1) {
    return "*($ptr) == *($s)";
  } else {
    return "!memcmp($ptr, ".B::cstring($s).", $l)";
  }
}

=item u_csize($size)
=item s_csize($size)

Returns the c-type as string to hold the unsigned or signed size elements,
long, int, short or char.

=cut

sub u_csize {
  my $size = shift;
  if ($size > 4294967296) {
    return "unsigned long";
  } elsif ($size > 65536) {
    return "unsigned int";
  } elsif ($size > 256) {
    return "unsigned short";
  } else {
    return "unsigned char";
  }
}

sub s_csize {
  my $size = shift;
  if ($size > 2147483648) {
    return "long";
  } elsif ($size > 32768) {
    return "int";
  } elsif ($size > 128) {
    return "short";
  } else {
    return "signed char";
  }
}

=back

=cut

1;
