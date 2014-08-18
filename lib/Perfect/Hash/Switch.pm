package Perfect::Hash::Switch;

use strict;
our $VERSION = '0.01';
#use warnings;
use Perfect::Hash;
use Perfect::Hash::C;
use integer;
use bytes;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);
use B ();
#use Config;

=head1 DESCRIPTION

Uses no hash function nor hash table, just generates a fast switch
table in C<C> as with C<gperf --switch>, for smaller dictionaries.

Generates a nested switch table, first switching on the
size and then on the best combination of keys. The difference to
C<gperf --switch> is the automatic generation of nested switch levels,
depending on the number of collisions, and it is optimized to use word size
comparisons if possible for the fixed length comparisons, which is faster
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
    $old = $l unless defined $old;
    if ($l == $old) {
      push @cand, $s;
    } elsif (@cand) {
      do_cand($FH, $old, \@cand, $dict);
      @cand = ();
      $old = $l;
    }
  }
  do_cand($FH, $old, \@cand, $dict) if @cand;
  print $FH "
    }
}
";
}
sub do_cand {
  my ($FH, $l, $cand, $dict) = @_;
  # switch on length
  print $FH "
    case $l: /* ", join(", ", @$cand)," */";
  if (@$cand == 1) { # only one candidate to check
    my $s0 = $cand->[0];
    my $v = $dict->{$s0};
    if ($l == 1) {
      $s0 = substr(B::cstring($s0),1,-1);
      $s0 =~ s/'/\\'/;
      print $FH "
      return *s == '$s0' ? $v : -1;";
    } else {
      print $FH "
      return memcmp(s, ",B::cstring($cand->[0]),", $l) ? -1 : $v;";
    }
  } else {
    # switch on the most diverse char in the strings
    do_switch($FH, $cand, $dict);
  }
}

sub do_switch {
  my ($FH, $cand, $dict) = @_;
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
  print $FH "
      switch (s[$i]) {";
  # TODO: collect @cand into buckets for the selected char
  # and switch on these
  my ($old_c, $new_case) = ('');
  for my $s (sort {substr($a,$i,1) cmp substr($b,$i,1) } @$cand) {
    my $c = substr($s, $i, 1);
    if ($new_case and $c ne $old_c) {
      print $FH "
        break;";
    }
    # TODO: if $h{$c} > 5-10 nest one more switch recursively
    if (0 and $h->{$c} > 8) {
      my @cand_c = map { substr($_,$i,1) eq $c } @$cand;
      do_switch($FH, \@cand_c, $dict);
    } else {
      my $v = $dict->{$s};
      my $qc = substr(B::cstring($c),1,-1);
      $qc =~ s/'/\\'/g;
      if ($h->{$c} == 1) {
        print $FH "
      case '$qc':";
        if (length($s) == 1) {
          print $FH "
        return s[$i] == '$qc' ? $v : -1;";
        } else {
          print $FH "
        return memcmp(s, ",B::cstring($s),", $l) ? -1 : $v;";
        }
      } else {
        if ($c ne $old_c) {
          print $FH "
      case '$qc':";
          $new_case = 1;
        }
        print $FH "
        if (!memcmp(s, ",B::cstring($s),", $l)) return $v;";
        $old_c = $c;
      }
    }
  }
  print $FH "
      }
      return -1;";
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
  __PACKAGE__->new("examples/words500")->save_c;
}

1;
