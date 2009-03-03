#   $Id: 684-output-ingres-get-sql.t,v 1.3 2009/02/28 06:54:57 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 7;

diag 'Ingres support is experimental';

use lib q{lib};
use_ok ('Parse::Dia::SQL');
use_ok ('Parse::Dia::SQL::Output');
use_ok ('Parse::Dia::SQL::Output::Ingres');

my $diasql =
  Parse::Dia::SQL->new(file => catfile(qw(t data TestERD.dia)), db => 'ingres');
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});

is($diasql->convert(), 1, q{Expect convert() == 1});

can_ok($diasql, q{get_output_instance});
my $subclass = $diasql->get_output_instance();
isa_ok(
  $subclass,
  q{Parse::Dia::SQL::Output::Ingres},
  q{Expect a Parse::Dia::SQL::Output::Ingres object}
);

__END__

