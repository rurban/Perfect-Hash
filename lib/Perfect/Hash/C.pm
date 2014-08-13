package Perfect::Hash::C;
use strict;
our $VERSION = '0.01';
our @ISA = qw(Perfect::Hash Exporter);
use B ();

use Exporter 'import';
our @EXPORT = qw(_save_c_array);

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
  use File::Basename 'basename';
  my $base = basename $fileprefix;
  open FH, ">", $fileprefix.".h" or die "$fileprefix.h: @!";
  print FH c_funcdecl($ph, $base).";\n";
  close FH;
  return ($fileprefix, $base);
}

sub save_c_header {
  my ($ph, $fileprefix, $base) = @_;
  my $FH;
  open $FH, ">", $fileprefix.".c" or die "$fileprefix.c: @!";
  print $FH "#include \"$base.h\"\n";
  if (!$ph->false_positives) { # check keys
    print $FH "#include <string.h>\n"; # for memcmp/strcmp
  }
  return $FH;
}

sub c_funcdecl {
  my ($ph, $base) = @_;
  if ($ph->option('-nul')) {
    "
long $base\_lookup(const char* s, int l)";
  } else {
    "
long $base\_lookup(const char* s)";
  }
}

=item _save_c_array FH, array

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

=item c_lib c_include

Returns a string with the required include path and libs to link to.

=cut

sub c_include { "" }

sub c_lib { "" }

=back

=cut
