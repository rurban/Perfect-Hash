package Perfect::Hash::Gperf;

use strict;
our $VERSION = '0.01';
#use warnings;
use Perfect::Hash;
use Perfect::Hash::C;
#use integer;
#use bytes;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);
#use B ();
#use Config;

=head1 DESCRIPTION

Uses no hash function nor hash table, just generates a gperf
table in C<C>.

=head1 METHODS

=over

=item new $filename, @options

All options are just passed through.

=cut

sub new { 
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my %options = map { $_ => 1 } @_;
  # enforce KEYFILE
  my $fn = "phash_keys.tmp";
  if (ref $dict eq 'ARRAY') {
    unlink $fn;
    open my $F, ">", $fn;
    print $F "%%\n";
    my $i = 0;
    my %dict;
    for (@$dict) {
      print $F $_."\n";
      $dict{$_} = $i++;
    }
    print $F "%%";
    close $F;
    $dict = \%dict;
  }
  elsif (ref $dict eq 'HASH') {
    open my $F, ">", $fn;
    for (sort keys %$dict) {
      print $F $_,"\t",$dict->{$_},"\n";
    }
    print $F "%%";
    close $F;
  } elsif (!ref $dict and ! -e $dict) {
    die "wrong dict argument. arrayref, hashref or filename expected";
  } else {
    my %hash;
    open my $d, "<", $dict or die; {
      local $/;
      my $i = 0;
      %hash = map {$_ => $i++ } split /\n/, <$d>;
    }
    close $d;
    $dict = \%hash;
  }
  return bless [$fn, \%options, $dict], $class;
}

=item save_c fileprefix, options

Generates a $fileprefix.c file.

=cut

sub save_c {
  my $ph = shift;
  my ($fn, $options, $dict) = ($ph->[0], $ph->[1], $ph->[2]);
  my ($fileprefix, $base) = $ph->save_h_header(@_);
  my %opts = ('-pic'      => '-P',
             #'-nul'      => '-l',
              '-7bit'     => '-7',
              '-switches' => '--switch=2',
             );
  my @opts = ("-l", "-C","-N$base\_lookup", "-H$base\_hash");
  for (keys %$options) {
    push @opts, $opts{$_} if exists $opts{$_}; 
  }
  my @cmd = ("gperf", @opts, $fn, ">$fileprefix.c");
  print join(" ",@cmd),"\n" if $ENV{TEST_VERBOSE};
  system(join(" ",@cmd));
}

=item perfecthash $ph, $key

dummy pure-perl variant just for testing.

=cut

sub perfecthash {
  my $ph = shift;
  my $dict = $ph->[2];
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
