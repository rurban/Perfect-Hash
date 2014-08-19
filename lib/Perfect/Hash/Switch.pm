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
    const l = strlen(s);"
  }
  print $FH "
    switch (l) {";
  # dispatch on l
  my ($old, @cand);
  for my $s (sort { length($a) <=> length($b) } keys %$dict) {
    my $l = bytes::length($s);
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

# length optimized memcmp
sub _strcmp_i {
  my ($ptr, $s, $l) = @_;
  my $u8s = $s;
  utf8::decode($u8s);
  if ($Config{d_quad} and $Config{longlongsize} == 16 and $l == 16) { # 128-bit qword
    my $quad = sprintf("0x%llx", unpack("Q", $s));
    my $quadtype = $Config{uquadtype};
    return "*($quadtype *)$ptr == $quad"."ULL /* $s */";
  } elsif ($Config{d_quad} and $Config{longlongsize} == 8 and $l == 8) {
    my $quad = sprintf("0x%lx", unpack("Q", $s));
    my $quadtype = $Config{uquadtype};
    return "*($quadtype *)$ptr == $quad"."ULL /* $u8s */";
  } elsif ($Config{longsize} == 8 and $l == 8) {
    my $long = sprintf("0x%lx", unpack("J", $s));
    return "*(long *)$ptr == $long /* $u8s */";
  } elsif ($Config{intsize} == 4 and $l == 4) {
    my $int = sprintf("0x%x", unpack("L", $s));
    return "*(int*)$ptr == $int /* $u8s */";
  } elsif ($l == 2) {
    my $short = sprintf("0x%x", unpack("S", $s));
    return "*(short*)$ptr == $short /* $u8s */";
  } elsif ($l == 1) {
    my $ord = ord($s);
    if ($ord >= 40 and $ord < 127) {
      return "*($ptr) == '$s'";
    } else {
      return "*($ptr) == $ord /* $s */";
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
  if ($l > 36) { # cutoff 36 for short words, not using memcmp.
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
        $s = substr($s, $n);
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
    print $FH "\n        ",_strcmp($s0, $l, $v);
  } else {
    # switch on the most diverse char in the strings
    _do_switch($ph, $FH, $cand);
  }
}

# handle candidate list of keys with equal length
# find the best char(s) to switch on
# tries char ranges 8,4,2,1 if length allows it (quad*,long*,int*,short*,char*)
sub _do_switch {
  my ($ph, $FH, $cand, $indent) = @_;
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
  print $FH "\n"," " x $space,"switch ((unsigned char)s[$i]) {";
  if ($options->{-debug}) {
    $maxc = scalar @$cand >= 5 ? 4 : scalar(@$cand) -1;
    printf("switch on $i in cand %s\n", join(",", @$cand[0..$maxc])) ;
  }
  print $FH " /* ",join(", ",@$cand)," */";
  # TODO: collect @cand into buckets for the selected char
  # and switch on these
  #my @c = map { substr($_,$i,1) } @$cand;
  my ($old_c, $new_case) = ('');
  for my $s (sort {substr($a,$i,1) cmp substr($b,$i,1) } @$cand) {
    my $c = substr($s, $i, 1);
    # if $h{$c} > 3 nest one more switch recursively
    my @cand_c;
    if ($h->{$c} > 3) {
      # check for recursive loop. XXX but still not good enough. maybe check for same $i also
      @cand_c = grep { substr($_,$i,1) eq $c ? $_ : undef } @$cand;
      if ($options->{-debug}) {
        my $maxc_c = scalar(@cand_c) >= 5 ? 4 : $#cand_c;
        printf("excess: %d cases on $i in cand %s => %s\n", $h->{$c},
               join(",", @$cand[0..$maxc]), join(",", @cand_c[0..$maxc]))
      }
    }
    if ($h->{$c} > 3 and @cand_c < @$cand) {
      my $len = scalar @cand_c;
      $indent++;
      print "recurse into $indent switch on $i with $len elements\n" if $options->{-debug};
      _do_switch($ph, $FH, \@cand_c, $indent);
      # maybe: restart loop without cand_c? No, the return below is pretty good.
      my @rest = grep { substr($_,$i,1) ne $c ? $_ : undef } @$cand;
      _do_switch($ph, $FH, \@rest, $indent);
      print $FH "\n"," " x $space,"}\n",
                " " x $space, "return -1;";
      return;
    } else {
      my $v = $dict->{$s};
      my $ord = ord($c);
      my $case = ($ord >= 40 and $ord < 127) ? "'$c':" : "$ord: /* $c */";
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
  print $FH "\n"," " x $space,"}\n";
  if ($indent == 1) {
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
