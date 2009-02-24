#   $Id: 001-new.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Test::More;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 2;

use_ok ('Parse::Dia::SQL');

my $diasql = Parse::Dia::SQL->new();
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});

__END__

