#   $Id: 101-generate-small-package-sql.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 5;

use_ok ('Parse::Dia::SQL');

# negative test - db2
my $diasql =  Parse::Dia::SQL->new( file => catfile(qw(t data TestERD.dia)), db => 'db2' );
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});

# TODO: Add test on return value - call wrapper
$diasql->convert();

my $sql = $diasql->generate_small_package_sql();
#diag($sql);

# Check order of statements
like(
  $sql,
  qr/drop sequence imageInfo_id.*create sequence imageInfo_id/s,
  q{drop, then create sequence imageInfo_id}
);


# negative test - mysql
$diasql = undef;
$diasql =  Parse::Dia::SQL->new( file => catfile(qw(t data TestERD.dia)), db => 'mysql' );
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});

# TODO: Add test on return value - call wrapper
$diasql->convert();

# expect empty string since mysql in *not* part of the statement
is($diasql->generate_small_package_sql(), q{}, q{expect empty string});



__END__

