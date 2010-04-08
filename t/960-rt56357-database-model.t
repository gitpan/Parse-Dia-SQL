#   $Id: 960-rt56357-database-model.t,v 1.1 2010/04/08 19:29:33 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 4;
 
use lib q{lib};
use_ok ('Parse::Dia::SQL');

my $diasql =
  Parse::Dia::SQL->new(file => catfile(qw(t data rt56357.dia)), db => 'postgres');
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});
can_ok($diasql, q{get_sql});

TODO: {
  local $TODO = "model type 'Database - Table' is not yet implemented";
  my $sql = undef;
  lives_ok(
    sub {  $sql = $diasql->get_sql() },
    q{get_sql should live on supported model type 'Database - Table'}
  );
}
# diag $sql;


__END__


=pod

=head1 DESCRIPTION

The I<database> model type was added to dia in recent versions. The
purpose of this test is to identify those models and issue a
meaningful warning.

=cut

