package Perfect::Hash::C;
our $VERSION = '0.01';

=head1 NAME

Perfect::Hash::C - generate C or XS code for perfect hashes

=head1 SYNOPSIS

    use Perfect::Hash;
    use Perfect::Hash::C;

    $hash->{chr($_)} = int rand(2) for 48..90;
    my $ph = Perfect::Hash->new($hash);
    $ph->save("ph.c");

    my @dict = split/\n/,`cat /usr/share.dict/words`;
    my $ph2 = Perfect::Hash->new(\@dict, -minimal);
    $ph2->save_xs("ph.inc");

=head1 DESCRIPTION

There exist various C or python libraries to generate code to access
perfect hashes and minimal versions thereof, but none in Perl. gperf
creates efficient C code and libraries, but is only usable for a small
number of keys.

=head1 METHODS

=over

=item save filename

Generates pure C code, with the perl values saved a C types.

=item save_xs filename

Generated XS code, with the perl values saved as perl types.

=cut

