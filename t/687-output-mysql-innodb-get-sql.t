#   $Id: 687-output-mysql-innodb-get-sql.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

diag 'Mysql-Innodb support is experimental';
plan tests => 1;
use_ok('Parse::Dia::SQL::Output::MySQL::InnoDB');

__END__
