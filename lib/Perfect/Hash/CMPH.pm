package Perfect::Hash::CMPH;

use strict;
our $VERSION = '0.01';
#use warnings;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);
use B ();
use Config;

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

Honored options are: I<-nul>

=cut

# TODO support arrayref and hashref converted to arrayrefs, as byte-packed vector
# for the cmph io_vector or io_byte_vector adapter.
sub new {
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my $size;
  # enforce KEYFILE
  my $fn = "pperf_keys.tmp";
  if (ref $dict eq 'ARRAY') {
    open my $F, ">", $fn;
    my $i = 0;
    my %dict;
    $size = scalar @$dict;
    for (@$dict) {
      print $F "$_\n";
      $dict{$_} = $i++;
    }
    close $F;
    $dict = \%dict;
  }
  elsif (ref $dict eq 'HASH') {
    open my $F, ">", $fn;
    for (sort keys %$dict) {
      print $F $_,"\t",$dict->{$_},"\n";
    }
    #print $F "%%";
    close $F;
    $size = scalar keys %$dict;
  } elsif (!ref $dict and ! -e $dict) {
    die "wrong dict argument. arrayref, hashref or filename expected";
  } else {
    $fn = $dict;
    # against -false-positive
    my %hash;
    open my $d, "<", $dict or die; {
      local $/;
      my $i = 0;
      %hash = map {$_ => $i++ } split /\n/, <$d>;
    }
    close $d;
    $dict = \%hash;
    $size = scalar keys %hash;
  }
  my $ph = _new($class, $fn, @_);
  if (grep /^-false-positives/, @_) {
    push @$ph, $dict; # at [3]
  }
  $ph->[2]->{size} = $size;
  return $ph;
}

=item perfecthash $ph

XS method. Returns the position of the found key in the file.

=item false_positives

=item option $ph

Access the option hash in $ph.

=cut

sub option {
  return $_[0]->[2]->{$_[1]};
}

=item save_c fileprefix, options

Generates a $fileprefix.c and $fileprefix.h file.

For all CMPH variants.

=cut

sub save_c {
  my $ph = shift;
  my $size = $ph->[2]->{size};
  require Perfect::Hash::C;
  Perfect::Hash::C->import();

  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my $FH = $ph->save_c_header($fileprefix, $base);
  # XXX need to initialize mphf from the temp FILE
  # into a memory buffer.
  print $FH "#include \"cmph.h\"\n";
  print $FH $ph->c_funcdecl($base)." {";
  # XXX check for false positives from dict at [3]
  my $l = $ph->option('-nul') ? "l" : "strlen(s)";
  print $FH "
    static const char *packed_mphf = ",B::cstring($ph->[1]),";
    return cmph_search_packed((void*)packed_mphf, (const char*)s, $l) % $size;
}
";
}

=item c_lib, c_include

TODO: to the installed Alien libpath

=cut

# quirks on temp. uninstalled -lcmph
sub c_include { " -Icmph-2.0/include" }

sub c_lib {
  # quirks on temp. uninstalled -lcmph
  my $l = " -Lcmph-2.0/lib -lcmph";
  # rpath not with darwin, solaris, msvc. we should rather install cmph locally or via Alien
  $l .= " -Wl,-rpath=cmph-2.0/lib" if $^O =~ /linux|bsd|cygwin$/ and $Config{cc} =~ /cc|clang/;
  if ($^O eq 'darwin' and $Config{ccflags} =~ /-DDEBUGGING/) {
    $l = " cmph-2.0/lib/libcmph.a"; # static to enable debugging
  }
  return $l;
}

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
