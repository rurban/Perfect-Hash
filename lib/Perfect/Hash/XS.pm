package Perfect::Hash::XS;
our $VERSION = '0.01';
use Perfect::Hash::C;
our @ISA = qw(Perfect::Hash::C Perfect::Hash);

=head1 NAME

Perfect::Hash::XS - generate perl XS code for perfect hashes

=head1 SYNOPSIS

    use Perfect::Hash;

    $hash->{chr($_)} = int rand(2) for 48..90;
    my $ph = new Perfect:Hash $hash;
    $ph->save_xs("ph.inc");

    my @dict = split/\n/,`cat /usr/share.dict/words`;
    my $ph2 = Perfect::Hash->new(\@dict, -minimal, -for-xs);
    $ph2->save_xs("ph1.inc");

=head1 DESCRIPTION

Optimized for sharedlib and PIC.

=head1 METHODS

=over

=item save_xs filename, options

Generated XS code, with the perl values saved as perl types.

=cut

sub save_xs {
  die 'nyi';
}
