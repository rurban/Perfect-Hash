package Perfect::Hash::C;
our $VERSION = '0.01';
our @ISA = qw(Perfect::Hash);

=head1 NAME

Perfect::Hash::C - generate C code for perfect hashes

=head1 SYNOPSIS

    use Perfect::Hash;

    $hash->{chr($_)} = int rand(2) for 48..90;
    my $ph = new Perfect:Hash $hash, -for-c;
    $ph->save_c("ph"); # => ph.c, ph.h

    my @dict = split/\n/,`cat /usr/share.dict/words`;
    my $ph2 = Perfect::Hash->new(\@dict, -minimal, -for-c);
    $ph2->save_c("ph2"); # => ph2.c, ph2.h

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

=item _save_c_header fileprefix, options

Internal helper method for save_c

=cut

sub _save_c_header {
  # refer to the class save_c method
  my $ph = shift;
  if (ref $ph eq __PACKAGE__ or ref $ph eq 'Perfect::Hash::C') {
    die "wrong class: ",ref $ph;
  }
  my $fileprefix = shift || "phash";
  use File::Basename 'basename';
  my $base = basename $fileprefix;
  #my @options = @_;
  my @H = @{$ph->[0]};
  my $FH;
  open $FH, ">", $fileprefix.".h" or die "$fileprefix.h: @!";
  print $FH "
static inline unsigned $base\_lookup(const char* s);
";
  close $FH;
  return ($fileprefix, $base);
}

=item _save_c_funcdecl ph, fileprefix, base

Internal helper method for save_c

=cut

sub _save_c_funcdecl {
  my ($ph, $fileprefix, $base) = @_;
  my $FH;
  open $FH, ">", $fileprefix.".c" or die "$fileprefix.c: @!";
  # non-binary only so far:
  print $FH "
#include \"$base.h\"

static inline unsigned $base\_lookup(const char* s) {";
  return $FH;
}

=item _save_c_array FH, array

Internal helper method for save_c

=cut

sub _save_c_array {
  my ($ident, $FH, $G) = @_;
  my $size = scalar @$G;
  for (0 .. int($size / 16)) {
    my $from = $_ * 16;
    my $to = $from + 15;
    print $FH " " x $ident;
    for ($from .. $to) {
      printf $FH "%3d,",$G->[$_];
      last if $to >= $size;
    }
    print $FH "\n";
  }
}

=back

=cut
