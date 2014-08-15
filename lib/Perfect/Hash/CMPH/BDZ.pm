package Perfect::Hash::CMPH::BDZ;

use strict;
our $VERSION = '0.01';
use Perfect::Hash::CMPH;
#use warnings;
our @ISA = qw(Perfect::Hash::CMPH Perfect::Hash Perfect::Hash::C);

=head1 DESCRIPTION

XS interface to the cmph-2.0 BDZ algorithm.
The MPFH minimal variant is L<Perfect::Hash::CMPH::BDZ_PH>.
See http://cmph.sourceforge.net/bdz.html

It is a simple, efficient, near-optimal space and practical algorithm
to generate a family of PHFs and MPHFs. It is also referred to as BPZ
algorithm because the work presented by Botelho, Pagh and Ziviani in
[2]. In the Botelho's PhD. dissertation [1] it is also referred to as
RAM algorithm because it is more suitable for key sets that can be
handled in internal memory.

The BDZ algorithm uses r-uniform random hypergraphs given by function
values of r uniform random hash functions on the input key set S for
generating PHFs and MPHFs that require O(n) bits to be stored. A
hypergraph is the generalization of a standard undirected graph where
each edge connects vertices. This idea is not new, see e.g. [8], but
we have proceeded differently to achieve a space usage of O(n) bits
rather than O(n log n) bits. Evaluation time for all schemes
considered is constant. For r=3 we obtain a space usage of
approximately 2.6n bits for an MPHF. More compact, and even simpler,
representations can be achieved for larger m. For example, for m=1.23n
we can get a space usage of 1.95n bits.

Our best MPHF space upper bound is within a factor of 2 from the
information theoretical lower bound of approximately 1.44 bits. We
have shown that the BDZ algorithm is far more practical than previous
methods with proven space complexity, both because of its simplicity,
and because the constant factor of the space complexity is more than 6
times lower than its closest competitor, for plausible problem
sizes. We verify the practicality experimentally, using slightly more
space than in the mentioned theoretical bounds.

=head1 METHODS

See L<Perfect::Hash::CMPH>

=head1 SEE ALSO

[1] F. C. Botelho. Near-Optimal Space Perfect Hashing
Algorithms. PhD. Thesis, Department of Computer Science, Federal
University of Minas Gerais, September 2008. Supervised by N. Ziviani.
Lhttp://cmph.sourceforge.net/papers/thesis.pdf<>

[2] F. C. Botelho, R. Pagh, N. Ziviani. Simple and space-efficient
minimal perfect hash functions. In Proceedings of the 10th
International Workshop on Algorithms and Data Structures (WADs'07),
Springer-Verlag Lecture Notes in Computer Science, vol. 4619, Halifax,
Canada, August 2007, 139-150.
L<http://cmph.sourceforge.net/papers/wads07.pdf>

=cut

# local testing: p -d -Ilib lib/Perfect/Hash/CMPH/BDZ.pm examples/words20
unless (caller) {
  require Perfect::Hash;
  &Perfect::Hash::_test(@ARGV)
}

1;
