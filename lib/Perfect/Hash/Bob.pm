package Perfect::Hash::Bob;

our $VERSION = '0.01';
use strict;
#use warnings;
use Perfect::Hash;
use Perfect::Hash::C;
our @ISA = qw(Perfect::Hash Perfect::Hash::C);

# For testing we started with the exe at first
#use XSLoader;
#XSLoader::load('Perfect::Hash::Bob');

=head1 DESCRIPTION

XS interface to bob jenkins perfect hashes.

Only for benchmarks yet:
So far only calls C<bob/perfect>, not our XS,
can only read limited \n delimited, value-less keyfiles,
is limited to the C<--prefix phash_hash>,
and overflows with larger number of keys (> ~25000)

=head1 METHDOS

=over

=item new $filename|hashref|arrayref @options

Can only handle arrayref or single column keyfiles yet. No values.

Honored options are:

-max-time  default: 60, disable with 0

=cut

sub new { 
  my $class = shift or die;
  my $dict = shift; #hashref, arrayref or filename
  my $options = Perfect::Hash::_handle_opts(@_);
  if (!exists $options->{'-max-time'}) {
    $options->{'-max-time'} = 60;
  } elsif (!$options->{'-max-time'}) {
    delete $options->{'-max-time'};
  }
  # see if we can use the executable, return undef if not
  # no PP nor XS fallback variant yet
  my $retval = system("bob/perfect --version"
                      .($^O eq 'MSWin32' ? ">NUL" : " >/dev/null"));
  if ($retval != 0) {
    return undef;
  }

  # enforce KEYFILE
  my $fn = "phash_keys.tmp";
  if (ref $dict eq 'ARRAY') {
    unlink $fn;
    open my $F, ">", $fn;
    my $i = 0;
    my %dict;
    for (@$dict) {
      print $F $_,"\n" if length($_);
      $dict{$_} = $i++;
    }
    close $F;
    $dict = \%dict;
  }
  elsif (ref $dict eq 'HASH') {
    open my $F, ">", $fn;
    for (sort keys %$dict) {
      print $F $_,"\n" if length($_);
    }
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
    $fn = $dict;
    $dict = \%hash;
  }
  if (!-f $fn or !-s $fn) {
    return undef;
  }
  return bless [$fn, $options, $dict], $class;
}

=item save_c prefix, options

prefix is ignored so far.

Generates F<phash_hash.c> and F<.h> files, which need to be linked
against F<bob/lookupa.o>

=cut

sub save_c {
  my $ph = shift;
  my ($fn, $options, $dict) = ($ph->[0], $ph->[1], $ph->[2]);
  my $fileprefix = "phash_hash";
  # fast or slow, minimal or not
  my @opts = ("-NPs", "phash");
  # since we need to redirect we need a shell
  # but if we got a shell we need to kill the exe and the shell
  my @cmd = ("bob/perfect", @opts, "<$fn",
             ($^O eq 'MSWin32' ? ">NUL" : " >/dev/null"));
  print join(" ",@cmd),"\n" if $ENV{TEST_VERBOSE};
  if ($options->{'-max-time'} and $^O =~ /linux|bsd|solaris|cygwin/) { # timeout
    use POSIX ":sys_wait_h";
    my $pid = fork;
    die "fork" if !defined $pid;
    if ($pid > 0) {
      eval {
        my $secs = 0; my $res;
        do {
          sleep ( 1 ); $secs++;
          $res = waitpid($pid, WNOHANG); # the forked perl
          warn "pid=$pid, res=$res, err=",$?,"\n" if $options->{'-debug'};
          $res = -1 if $secs >= $options->{'-max-time'};
        } while ($res == 0); # check if pid is still running or timed out
        $res = waitpid($pid, WNOHANG);
        warn "res=$res, err=",$?,"\n" if $options->{'-debug'};
        if ($res == 0) { # check if pid is still running. with exec it is not.
          kill 9, -$pid; # the group
          warn "timeout: perfect killed\n";
        }
      }
    } elsif ($pid == 0) {
      setpgrp(0, 0); # with exec sets the process status to T for stopped and traced.
      # undetectable to waitpid.
      # however with system it creates a proper detectable and killable child hierarchy.
      system(join(" ",@cmd));
      exit(0);
    }
  } else {
    system(join(" ",@cmd));
  }
  my $errcode = $? >> 8;
  unlink $fn if $fn eq "phash_keys.tmp" and !$errcode;
  open my $H, ">>", "$fileprefix.h";
  if ($options->{'-nul'}) {
    print $H "#define phash_hash_lookup(k,l) mph_phash_s((k),(l))\n";
  } else {
    print $H "#define phash_hash_lookup(k) mph_phash((k))\n";
  }
  close $H;
  return $errcode;
}

=item perfecthash key

dummy, for testing only. Use the generated C function instead.

=cut

sub perfecthash {
  my $ph = shift;
  my $dict = $ph->[2];
  my $key = shift;
  return exists $dict->{$key} ? $dict->{$key} : undef;
}

=item false_positives

Returns 1 if the hash might return false positives, i.e. will return
the index of an existing key when you searched for a non-existing key.

The default is undef, unless you created the hash with the option
C<-false-positives>.

=cut

sub false_positives {}

=item option $ph

Access the option hash in $ph.

=cut

sub option {
  return $_[0]->[1]->{$_[1]};
}

sub c_include { " -Ibob" }

sub c_lib { " bob/lookupa.o" }

=back

=head1 LICENSE

The code of the bob jenkins perfect hash is under the public domain.

However, code generated by this library is covered under the same terms
as perl itself, which is dual licensed under the GPL v2 and Artistic 2
licenses.

=cut

1;
