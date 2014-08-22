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
    const unsigned int l = strlen(s);"
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

# handle candidate list of keys with equal length
# either 1 or do a nested switch
# TODO: check char* alignment on non-intel platforms for memcmp_const_str
sub _do_cand {
  my ($ph, $FH, $l, $cand) = @_;
  my ($dict, $options) = ($ph->[0], $ph->[1]);
  # switch on length
  print $FH "
      case $l: "; #/* ", join(", ", @$cand)," */";
  if (@$cand == 1) { # only one candidate to check
    my $s0 = $cand->[0];
    my $v = $dict->{$s0};
    print $FH "\n        ",memcmp_const_str($s0, $l, $v, 1);
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
        print $FH "\n    "," " x $space, memcmp_const_str($s, $l, $v);
        $new_case = 1;
      } else {
        if ($c ne $old_c) {
          print $FH "\n  "," " x $space,"case $case";
          $new_case = 1;
        }
        print $FH "\n    "," " x $space, memcmp_const_str($s, $l, $v);
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

Returns undef. Switch always checks the keys.

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
