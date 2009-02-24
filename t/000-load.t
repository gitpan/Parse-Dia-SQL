# $Id: 000-load.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Test::More tests => 1;
use Config;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

BEGIN {
  use_ok( 'Parse::Dia::SQL' );
}

diag( "Testing Parse::Dia::SQL $Parse::Dia::SQL::VERSION, Perl $], $^X, archname=$Config{archname}, byteorder=$Config{byteorder}" );

__END__
