package Perfect::Hash::CMPH;

use strict;
our $VERSION = '0.01';
#use warnings;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);

use XSLoader;
XSLoader::load('Perfect::Hash::CMPH');

=head1 DESCRIPTION

XS interface to the cmph library, the current state of the art library
for perfect hashes and minimal perfect hashes.

L<http://cmph.sourceforge.net>

=head1 METHODS

=over

=item new $filename, @options

filename only so far

=cut

# TODO support arrayref and hashref converted to arrayrefs, as byte-packed vector
# for the cmph io_vector or io_byte_vector adapter.
sub new {
  return _new(@_);
}

=item perfecthash $ph

XS method

=item false_positives

Returns undef, as cmph hashes always store the keys.

=cut

sub false_positives {
  return undef;
}

=item option $ph

Access the option hash in $ph.

=cut

sub option {
  return $_[0]->[1]->{$_[1]};
}

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

for all CMPH variants.

=cut

sub save_c {
  my $ph = shift;
  require Perfect::Hash::C;
  Perfect::Hash::C->import();
  my $dump = $ph->[2];

  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  print $FH "#include \"cmph.h\"\n";
  print $FH $ph->c_funcdecl($base)." {";
  print $FH "
    FILE *fd = fopen(\"$dump\", \"r\");
    cmph_t *mphf = cmph_load(fd);
    return cmph_search(mphf, s, ";
  if ($ph->option('-nul')) {
    print $FH "len";
  } else {
    print $FH "strlen(s)";
  }
  print $FH ");
}";
}

=item c_lib, c_include

TODO: to the installed Alien libpath

=cut

sub c_include { " -Icmph-2.0/include" }

sub c_lib { " -Wl,-rpath=cmph-2.0/lib -Lcmph-2.0/lib -lcmph" }

=back

=head1 LICENSE

The code of the cmph library and this perl library is dual licensed under
the B<LGPL version 2> and B<MPL 1.1> licenses. Please refer to the LGPL-2
and MPL-1.1 files in the F<cmph> subdirectory for the full description of
each of the licenses.

For cxxmph, the files F<stringpiece.h> and F<MurmurHash2> are covered by the
BSD and MIT licenses, respectively.

=cut

1;
