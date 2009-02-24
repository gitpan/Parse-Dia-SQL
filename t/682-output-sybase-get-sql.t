#   $Id: 682-output-sybase-get-sql.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan skip_all => 'Sybase support is experimental';

__END__

plan tests => 16 ;

use lib q{lib};
use_ok ('Parse::Dia::SQL');
use_ok ('Parse::Dia::SQL::Output');
use_ok ('Parse::Dia::SQL::Output::Sybase');

#my $diasql =  Parse::Dia::SQL->new( file => catfile(qw(t data TestERD.dia)), db => 'sybase');
my $diasql =  Parse::Dia::SQL->new( file => catfile(qw(t data TestERD.dia)), db => 'db2');
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});
is($diasql->convert(), 1, q{Expect convert to return 1});

my $sql = $diasql->get_sql;
#diag('TODO: Check output from get_sql');
#diag($sql);

# The drop index syntax is special for sybase (and mssql) in that it
# includes the tablename:

like($sql, qr/.* 
drop \s+ index \s+ imageInfo\.idx_iimd5 \s* (;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ imageInfo\.idx_iiid(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ subImageInfo\.idx_siiid(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ subImageInfo\.idx_siips(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ imageCategoryList\.idx_iclidnm(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ userInfo\.idx_uinm(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ userInfo\.idx_uiid(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ userAttribute\.idx_uauiid(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ userImageRating\.idx_uiruid(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ attributeCategory\.idx_acid(;)?
.*/six);

like($sql, qr/.*
drop \s+ index \s+ userSession\.idx_usmd5(;)?
.*/six);


__END__

