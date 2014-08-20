package Perfect::Hash::Switch;

use strict;
our $VERSION = '0.01';
#use warnings;
use Perfect::Hash;
use Perfect::Hash::C;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);
use Config;
use integer;
use bytes;
use B ();

=head1 DESCRIPTION

Uses no hash function nor hash table, just generates a fast switch
table in C<C> as with C<gperf --switch>, for smaller dictionaries.

Generates a nested switch table, first switching on the size and then
on the best combination of keys. The difference to C<gperf --switch>
is the automatic generation of nested switch levels, depending on the
number of collisions, and it is optimized to use word size comparisons
for the fixed length comparisons on short words, which is ~1.5x faster
then C<memcmp>.

I<TODO: optimize with more sse ops>

=head1 METHODS

=over

=item new $filename, @options

All options are just passed through.

=cut

sub new { 
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my %options = map { $_ => 1 } @_;
  # enforce HASHREF
  if (ref $dict eq 'ARRAY') {
    my $hash = {};
    my $i = 0;
    $hash->{$_} = $i++ for @$dict;
    $dict = $hash;
  }
  elsif (ref $dict ne 'HASH') {
    if (!ref $dict and -e $dict) {
      my (@keys, $hash);
      open my $d, "<", $dict or die; {
        local $/;
        @keys = split /\n/, <$d>;
        #TODO: check for key<ws>value or just lineno
      }
      close $d;
      my $i = 0;
      $hash->{$_} = $i++ for @keys;
      $dict = $hash;
    } else {
      die "wrong dict argument. arrayref, hashref or filename expected";
    }
  }
  return bless [$dict, \%options], $class;
}

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

=cut

sub save_c {
  my $ph = shift;
  my ($dict, $options) = ($ph->[0], $ph->[1]);

  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  print $FH $ph->c_funcdecl($base)." {";
  unless ($ph->option('-nul')) {
    print $FH "
    const int l = strlen(s);"
  }
  print $FH "
    switch (l) {";
  # dispatch on l
  my ($old, @cand);
  for my $s (sort { length($a) <=> length($b) } keys %$dict) {
    my $l = bytes::length($s);
    next if !$l; # skip saving/checking empty strings
    #print "l=$l, old=$old, s=$s\n" if $options->{-debug};
    $old = $l unless defined $old;
    if ($l != $old and @cand) {
      print "dump l=$old: [",join(" ",@cand),"]\n" if $options->{-debug};
      _do_cand($ph, $FH, $old, \@cand);
      @cand = ();
    }
    push @cand, $s;
    #print "push $s\n" if $options->{-debug};
    $old = $l;
  }
  print "rest l=$old: [",join(" ",@cand),"]\n" if $options->{-debug};
  _do_cand($ph, $FH, $old, \@cand) if @cand;
  print $FH "
    }
}
";
}

# wouldn't it be nice if perl5 core would provide a utf8::valid function?
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

# length optimized memcmp
sub _strcmp_i {
  my ($ptr, $s, $l) = @_;
  # $s via byte::substr might be a non-conforming utf8 part (split in the middle).
  # if so what should we do? only used for comments, but it screws up emacs or
  # other strict encoding detectors. and no, utf8::valid does not work, because
  # it returns when the utf8 flag is off
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

# it's the last statement if $last, otherwise as fallthrough to the next case statement.
# do away with most memcmp for shorter strings. cutoff 36 (TODO: try higher cutoffs, 128)
# TODO: might need to check run-time char* alignment on non-intel platforms
sub _strcmp {
  my ($s, $l, $v, $last) = @_;
  my $cmp;
  if ($l == 0) {
    return "0"; # empty string is false, this key does not exist (added by ourself most likely)
  } elsif ($l > 36) { # cutoff 36 for short words, not using memcmp.
    $cmp = _strcmp_i("s", $s, $l);
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
      $cmp = "$cmp\n\t\t&& "._strcmp_i($ptr, $s, $n);
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

# memcmp vs wordsize cmp via _strcmp_i(): (mac air)
#switch       0.005779  0.002551 0.307492   352346    35152  -1opt (2000)
#          => 0.004587  0.004156 0.553640  1038117    51536  -1opt
#switch       0.006598  0.003342 0.165452    15018    22864  -1opt (127)
#          => 0.004707  0.001989 0.171876    21062    22840

# handle candidate list of keys with equal length
# either 1 or do a nested switch
# TODO: check char* alignment on non-intel platforms for _strcmp
sub _do_cand {
  my ($ph, $FH, $l, $cand) = @_;
  my ($dict, $options) = ($ph->[0], $ph->[1]);
  # switch on length
  print $FH "
      case $l: "; #/* ", join(", ", @$cand)," */";
  if (@$cand == 1) { # only one candidate to check
    my $s0 = $cand->[0];
    my $v = $dict->{$s0};
    print $FH "\n        ",_strcmp($s0, $l, $v, 1);
  } else {
    # switch on the most diverse char in the strings
    _do_switch($ph, $FH, $cand, 1);
  }
}

sub _list_max5 {
  my $list = shift;
  my $last = scalar @$list >= 5 ? 4 : scalar(@$list) -1;
  return join(" ", @$list[0..$last]) . (scalar @$list >= 5 ? "..." : "");
}

# handle candidate list of keys with equal length
# find the best char(s) to switch on
# tries char ranges 8,4,2,1 if length allows it (quad*,long*,int*,short*,char*)
sub _do_switch {
  my ($ph, $FH, $cand, $last, $indent) = @_;
  $indent = 1 unless $indent;
  my ($dict, $options) = ($ph->[0], $ph->[1]);
  # find the best char in @cand to switch on
  my $maxkeys = [0,0,undef];
  my $l = bytes::length($cand->[0]);
  for my $i (0 .. $l-1) {
    my %h = ();
    for my $c (map { substr($_,$i,1) } @$cand) {
      $h{$c}++;
    }
    # find max of keys, i-th char in @cand
    my $keys = scalar keys %h;
    $maxkeys = [$keys,$i,\%h] if $keys > $maxkeys->[0];
    last if $keys == scalar @$cand;
  }
  my $i = $maxkeys->[1];
  my $h = $maxkeys->[2];
  my $space = 4 + (4 * $indent);
  my $maxc;
  print $FH "\n"," " x $space,"switch (s[$i]) {";
  if ($options->{-debug}) {
    printf("switch on $i in [%s]\n", _list_max5($cand));
  }
  print $FH " /* ",join(", ",@$cand)," */";
  # TODO: collect @cand into buckets for the selected char
  # and switch on these
  #my @c = map { substr($_,$i,1) } @$cand;
  my ($old_c, $new_case) = ('');
  for my $s (sort {substr($a,$i,1) cmp substr($b,$i,1) } @$cand) {
    my $c = substr($s, $i, 1);
    my $ord = ord($c);
    my $case = ($ord >= 40 and $ord < 127) ? "'$c':" : "$ord:";
    # if $h{$c} > 3 nest one more switch recursively
    my @cand_c;
    if ($h->{$c} > 3) {
      # check for recursive loop. XXX but still not good enough. maybe check for same $i also
      @cand_c = grep { substr($_,$i,1) eq $c ? $_ : undef } @$cand;
      if ($options->{-debug}) {
        printf("excess: %d cases on $i in [%s] => [%s]\n", $h->{$c},
               _list_max5($cand), _list_max5(\@cand_c));
      }
    }
    if ($h->{$c} > 3 and @cand_c < @$cand) {
      my $len = scalar @cand_c;
      $indent++;
      print "recurse into $indent switch on $i with $len elements\n" if $options->{-debug};
      print $FH "\n  "," " x $space,"default: /* split into 2 switches */";
      _do_switch($ph, $FH, \@cand_c, 0, $indent);
      # maybe: restart loop without cand_c? No, the return below is pretty good.
      my @rest = grep { substr($_,$i,1) ne $c ? $_ : undef } @$cand;
      print $FH "\n  "," " x $space,"  /* fallthru to other half */";
      _do_switch($ph, $FH, \@rest, $last & 1, $indent);
      print $FH "\n"," " x $space,"}";
      print $FH "\n"," " x $space, "return -1;" if $last;
      return;
    } else {
      my $v = $dict->{$s};
      if ($new_case and $c ne $old_c) {
        print $FH "\n    "," " x $space,"break;";
      }
      if ($h->{$c} == 1) {
        print $FH "\n  "," " x $space,"case $case";
        print $FH "\n    "," " x $space, _strcmp($s, $l, $v);
        $new_case = 1;
      } else {
        if ($c ne $old_c) {
          print $FH "\n  "," " x $space,"case $case";
          $new_case = 1;
        }
        print $FH "\n    "," " x $space, _strcmp($s, $l, $v);
        $old_c = $c;
      }
    }
  }
  print $FH "\n  "," " x $space,"default:\n    ",
                 " " x $space,"return -1;" if $last;
  print $FH "\n"," " x $space,"}";
  if ($indent == 1 and $last) {
    print $FH "\n"," " x $space, "return -1;",
  }
}

=item perfecthash $ph, $key

dummy pure-perl variant just for testing.

=cut

sub perfecthash {
  my $ph = shift;
  my $dict = $ph->[0];
  my $key = shift;
  return exists $dict->{$key} ? $dict->{$key} : undef;
}

=item false_positives

Returns undef, always checks the keys.

=cut

sub false_positives {}

=item option $ph

Access the option hash in $ph.

=cut

sub option {
  return $_[0]->[1]->{$_[1]};
}

=item c_lib, c_include

empty as Switch needs no external dependencies.

=cut

sub c_include { "" }

sub c_lib { "" }

=back

=cut

unless (caller) {
  __PACKAGE__->new(@ARGV ? @ARGV : "examples/words20")->save_c;
}

1;
