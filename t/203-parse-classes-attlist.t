#   $Id: 203-parse-classes-attlist.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 47;

use_ok ('Parse::Dia::SQL');

my $diasql =  Parse::Dia::SQL->new( file => catfile(qw(t data TestERD.dia)), db => 'mysql' );
isa_ok($diasql, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});

# TODO: Add test on return value - call wrapper
$diasql->convert();

my $classes = $diasql->get_classes_ref();

# Expect an array ref with 14 elements
isa_ok($classes, 'ARRAY');
cmp_ok(scalar(@$classes), q{==}, 14, q{Expect 14 classes});

# Hash with class/view names as keys and attribute list as (hashref) elements
my %attList = (
    imageInfo => [
        [ 'id',            'numeric (18)',  '',                    '2', undef ],
        [ 'insertionDate', 'timestamp',     'now() not null',      '0', undef ],
        [ 'md5sum',        'char (32)',     'not null',            '0', undef ],
        [ 'binaryType',    'varchar (16)',  '\'jpg\' null',        '0', undef ],
        [ 'name',          'varchar (64)',  'not null',            '0', undef ],
        [ 'locationList',  'varchar (128)', '\'//imgserver.org\'', '0', undef ],
        [ 'description',   'varchar (128)', 'null',                '0', undef ]
    ],
    users_view => [
        [ 'id',                                        '', '', '0', undef ],
        [ 'birthDate',                                 '', '', '0', undef ],
        [ 'name ||\'<\'|| email ||\'>\' as whoIsThis', '', '', '0', undef ],
        [ 'currentCategory',                           '', '', '0', undef ],
        [ 'acctBalance',                               '', '', '0', undef ],
        [ 'active',                                    '', '', '0', undef ]
    ],
    whorated_view => [
        [ 'a.name',                  '', '', '0', undef ],
        [ 'count (*) as numRatings', '', '', '0', undef ]
    ],
    ratings_view => [
        [ 'b.name',   '', '', '0', undef ],
        [ 'c.md5sum', '', '', '0', undef ],
        [ 'a.rating', '', '', '0', undef ]
    ],
    extremes => [
        [ 'name',    'varchar (32)', '', '2', undef ],
        [ 'colName', 'varchar (64)', '', '0', undef ],
        [ 'minVal',  'numeric (15)', '', '0', undef ],
        [ 'maxVal',  'numeric (15)', '', '0', undef ]
    ],
    userSession => [
        [ 'userInfo_id',   'numeric (18)', '', '2', undef ],
        [ 'md5sum',        'char (32)',    '', '2', undef ],
        [ 'insertionDate', 'timestamp',    '', '0', undef ],
        [ 'expireDate',    'timestamp',    '', '0', undef ],
        [ 'ipAddress',     'varchar (24)', '', '0', undef ]
    ],
    attributeCategory => [
        [ 'id',            'numeric (18)',  '', '2', undef ],
        [ 'attributeDesc', 'varchar (128)', '', '0', undef ]
    ],
    userImageRating => [
        [ 'userInfo_id',  'numeric (18)', '', '2', undef ],
        [ 'imageInfo_id', 'numeric (15)', '', '2', undef ],
        [ 'rating',       'integer',      '', '0', undef ]
    ],
    userAttribute => [
        [ 'userInfo_id',          'numeric (18)',  '', '2', undef ],
        [ 'attributeCategory_id', 'numeric (18)',  '', '2', undef ],
        [ 'numValue',             'numeric (5,4)', '', '0', undef ]
    ],
    userInfo => [
        [ 'id',              'numeric (18)',   '', '2', undef ],
        [ 'insertionDate',   'timestamp',      '', '0', undef ],
        [ 'md5sum',          'char (32)',      '', '0', undef ],
        [ 'birthDate',       'timestamp',      '', '0', undef ],
        [ 'gender',          'char (1)',       '', '0', undef ],
        [ 'name',            'varchar (32)',   '', '0', undef ],
        [ 'email',           'varchar (96)',   '', '0', undef ],
        [ 'currentCategory', 'varchar (32)',   '', '0', undef ],
        [ 'lastDebitDate',   'timestamp',      '', '0', undef ],
        [ 'acctBalance',     'numeric (10,2)', '', '0', undef ],
        [ 'active',          'integer',        '', '0', undef ]
    ],
    imageAttribute => [
        [ 'imageInfo_id',         'numeric (18)', '', '2', undef ],
        [ 'attributeCategory_id', 'numeric (18)', '', '2', undef ],
        [ 'numValue',             'numeric (8)',  '', '0', undef ],
        [ 'category',             'numeric (4)',  '', '0', undef ]
    ],
    categoryNames => [ [ 'name', 'varchar (32)', '', '2', undef ] ],
    imageCategoryList => [
        [ 'imageInfo_id', 'numeric (18)', '', '2', undef ],
        [ 'name',         'varchar (32)', '', '2', undef ]
    ],
    subImageInfo => [
        [ 'imageInfo_id', 'numeric (18)', '', '2', undef ],
        [ 'pixSize',      'integer',      '', '2', undef ]
    ],
);

# Check that each class has of the expected attList attributes
foreach my $class (@$classes) {
  #diag (Dumper($class));

  isa_ok($class, 'HASH');
  ok(exists($attList{$class->{name}}));

  # check contents
  is_deeply(
			$class->{attList},
			$attList{ $class->{name} },
			q{attList for } . $class->{name}
		   );

  # remove key-value pair from hash
  delete $attList{$class->{name}};
} 

# Expect no classes left now
cmp_ok(scalar(keys %attList), q{==}, 0, q{Expect 0 classes});

__END__

