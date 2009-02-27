#   $Id: 684-output-ingres-get-sql.t,v 1.2 2009/02/24 10:10:11 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 6;

diag 'Ingres support is experimental';

use lib q{lib};
use_ok ('Parse::Dia::SQL');
use_ok ('Parse::Dia::SQL::Output');
use_ok ('Parse::Dia::SQL::Output::Ingres');

my $diasql =
  Parse::Dia::SQL->new(file => catfile(qw(t data TestERD.dia)), db => 'ingres');
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});
can_ok($diasql, q{get_output_instance});
my $subclass = $diasql->get_output_instance();
isa_ok(
  $subclass,
  q{Parse::Dia::SQL::Output::Ingres},
  q{Expect a Parse::Dia::SQL::Output::Ingres object}
);

__END__

