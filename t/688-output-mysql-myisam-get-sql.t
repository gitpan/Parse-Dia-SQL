#   $Id: 688-output-mysql-myisam-get-sql.t,v 1.3 2009/02/28 06:54:57 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 8;

diag 'MySQL MyISAM support is experimental';

use lib q{lib};
use_ok ('Parse::Dia::SQL');
use_ok ('Parse::Dia::SQL::Output');
use_ok ('Parse::Dia::SQL::Output::MySQL');
use_ok ('Parse::Dia::SQL::Output::MySQL::MyISAM');

my $diasql =
  Parse::Dia::SQL->new(file => catfile(qw(t data TestERD.dia)), db => 'mysql-myisam');
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});
can_ok($diasql, q{get_sql});
my $sql = $diasql->get_sql();

isa_ok(
  $diasql->get_output_instance(),
  q{Parse::Dia::SQL::Output::MySQL::MyISAM},
  q{Expect Parse::Dia::SQL::Output::MySQL::MyISAM to be used as back-end}
);

#diag($sql);

like(
  $sql,
  qr/ENGINE=MyISAM DEFAULT CHARSET=latin1/,
  q{Expect sql to contain ENGINE=MyISAM DEFAULT CHARSET=latin1}
);

__END__
