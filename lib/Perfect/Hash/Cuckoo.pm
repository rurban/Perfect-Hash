package Perfect::Hash::Cuckoo;

our $VERSION = '0.01';
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::C;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);

=head1 DESCRIPTION

Generate non-perfect but fast Cuckoo hashes, with two universal hash
functions f and g into two tables of load factor 50%, guaranteeing
constant lookup and insertion time. Since Cuckoo hashes guarantee
constant worst case search time, we added it here. Contrary to
traditional perfect hashes, Cuckoo hashes can also be used for
insertions and deletions with a simple check if the table is static
or dynamic before extending it.

Only for benchmarks yet. Still just a dummy placeholder.

A study by Zukowski et al. has shown that cuckoo hashing is much
faster than chained hashing for small, cache-resident hash tables on
modern processors:

Zukowski, Marcin; Heman, Sandor; Boncz, Peter (June 2006).
"Architecture-Conscious Hashing". Proceedings of the
International Workshop on Data Management on New Hardware (DaMoN).
L<https://www.cs.cmu.edu/~damon2006/pdf/zukowski06archconscioushashing.pdf>

=head1 METHODS

=over

=item new $filename|hashref|arrayref @options

Can only handle arrayref or single column keyfiles yet. No values.

Still a dummy placeholder.

Honored options are:

C<-pic>, C<-nul>

=cut

sub new {
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my $options = Perfect::Hash::_handle_opts(@_);
  my ($keys, $values) = _dict_init($dict);
  # XXX optimize the 2 uhash functions here
  my $uhash = [];
  return bless [$uhash, $options, $keys, $values], $class;
}

=item save_c prefix, options

Generates F<$prefix_hash.c> and F<.h> files with no external dependencies.

=cut

sub save_c {
  my $ph = shift;
  my ($options, $keys) = ($ph->[1], $ph->[2]);
  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  # print $FH "#include <string.h>\n" if @$C or !$ph->option('-nul');
  print $FH $ph->c_hash_impl($base);
  print $FH $ph->c_funcdecl($base)." {\n";
  print $FH "  int l = strlen(s);" unless $ph->option('-nul');
  my $size = scalar @$keys;
  my $type = u_csize($size);
  if (!$ph->false_positives) { # store keys
    if ($ph->option('-pic')) {
      c_stringpool($FH, $keys);
    } else {
      print $FH "
  /* keys */
  static const char* keys[] = {\n";
      _save_c_array(4, $FH, $keys, "\"%s\"");
      print $FH "  };";
    }
  }
  # ...
  print $FH "
  return -1;\n";
  print $FH "}\n";
  close $FH;
}

=item c_hash_impl $ph, $base

String for C code for the 2 hash functions. Honors C<-nul>.

=cut

# XXX use the two randomly generated uhash params to generate 2 hash funcs
sub c_hash_impl {""}

=item perfecthash key

dummy, for testing only. Use the generated C function instead.

=cut

sub perfecthash {
  my $ph = shift;
  my ($keys, $values) = ($ph->[2], $ph->[3]);
  my $key = shift;
  my $dict = $ph->[4];
  if (!$dict) {
    for my $i (0 .. scalar(@$keys)-1) {
      $dict->{$keys->[$i]} = $values->[$i];
    }
  }
  return exists $dict->{$key} ? $dict->{$key} : undef;
}

=item false_positives

Returns 1 if the hash might return false positives, i.e. will return
the index of an existing key when you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>.

=cut

sub false_positives {
  return exists $_[0]->[1]->{'-false-positives'};
}

=item option $ph

Access the option hash in $ph.

=cut

sub option {
  return $_[0]->[1]->{$_[1]};
}

#sub c_include { }
#sub c_lib { }

=back

=cut

1;
