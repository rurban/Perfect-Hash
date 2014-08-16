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
table in C<C>, for smaller dictionaries.

This is similar to -pearson8 only recommended for small dictionary
sizes < 256. Generates a nested switch table, first switching on the
size and then on the keys. I<Probably optimized on word-size sse ops>

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
    } else {
      print $FH "
    case $old: /* ", join(", ", @cand)," */";
      if (@cand == 1) {
        my $v = $dict->{$s};
        print $FH "
      return memcmp(s, ",B::cstring($cand[0]),", l) ? -1 : $v;";
      } else {
        # prefix trie or word cmp or just binary search? nothing yet
        for (@cand) {
          my $v = $dict->{$_};
          print $FH "
      if (!memcmp(s, ",B::cstring($_),", l)) return $v;";
        }
          print $FH "
      return -1;";
      }
      @cand = ();
      $old = $l;
    }
  }
  print $FH "
    }
}
";
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

1;
