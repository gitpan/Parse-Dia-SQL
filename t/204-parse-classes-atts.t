#   $Id: 204-parse-classes-atts.t,v 1.1 2009/02/23 07:36:17 aff Exp $

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
my %atts = (

    imageInfo => {
        'binarytype' =>
          [ 'binaryType', 'varchar (16)', '\'jpg\' null', '0', undef ],
        'name' => [ 'name', 'varchar (64)', 'not null', '0', undef ],
        'description' => [ 'description', 'varchar (128)', 'null', '0', undef ],
        'md5sum'       => [ 'md5sum', 'char (32)', 'not null', '0', undef ],
        'fmorg'        => [],
        'locationlist' => [
            'locationList', 'varchar (128)', '\'//imgserver.org\'', '0', undef
        ],
        'public' => [],
        'id'     => [ 'id', 'numeric (18)', '', '2', undef ],
        'insertiondate' =>
          [ 'insertionDate', 'timestamp', 'now() not null', '0', undef ]
    },
    subImageInfo => {
        'fmorg'        => [],
        'pixsize'      => [ 'pixSize', 'integer', '', '2', undef ],
        'imageinfo_id' => [ 'imageInfo_id', 'numeric (18)', '', '2', undef ]
    },
    imageCategoryList => {
        'fmorg'        => [],
        'imageinfo_id' => [ 'imageInfo_id', 'numeric (18)', '', '2', undef ],
        'name'         => [ 'name', 'varchar (32)', '', '2', undef ]
    },
    categoryNames => {
        'fmorg'  => [],
        'public' => [],
        'name'   => [ 'name', 'varchar (32)', '', '2', undef ]
    },
    imageAttribute => {
        'numvalue' => [ 'numValue', 'numeric (8)', '', '0', undef ],
        'fmorg'    => [],
        'attributecategory_id' =>
          [ 'attributeCategory_id', 'numeric (18)', '', '2', undef ],
        'imageinfo_id' => [ 'imageInfo_id', 'numeric (18)', '', '2', undef ],
        'category'     => [ 'category',     'numeric (4)',  '', '0', undef ]
    },
    userInfo => {
        'currentcategory' =>
          [ 'currentCategory', 'varchar (32)', '', '0', undef ],
        'birthdate'     => [ 'birthDate',     'timestamp',    '', '0', undef ],
        'active'        => [ 'active',        'integer',      '', '0', undef ],
        'name'          => [ 'name',          'varchar (32)', '', '0', undef ],
        'md5sum'        => [ 'md5sum',        'char (32)',    '', '0', undef ],
        'email'         => [ 'email',         'varchar (96)', '', '0', undef ],
        'fmorg'         => [],
        'lastdebitdate' => [ 'lastDebitDate', 'timestamp',    '', '0', undef ],
        'acctbalance' => [ 'acctBalance', 'numeric (10,2)', '', '0', undef ],
        'id'          => [ 'id',          'numeric (18)',   '', '2', undef ],
        'insertiondate' => [ 'insertionDate', 'timestamp', '', '0', undef ],
        'gender'        => [ 'gender',        'char (1)',  '', '0', undef ]
    },
    userAttribute => {
        'numvalue' => [ 'numValue', 'numeric (5,4)', '', '0', undef ],
        'fmorg'    => [],
        'attributecategory_id' =>
          [ 'attributeCategory_id', 'numeric (18)', '', '2', undef ],
        'userinfo_id' => [ 'userInfo_id', 'numeric (18)', '', '2', undef ]
    },
    userImageRating => {
        'fmorg'        => [],
        'imageinfo_id' => [ 'imageInfo_id', 'numeric (15)', '', '2', undef ],
        'userinfo_id'  => [ 'userInfo_id', 'numeric (18)', '', '2', undef ],
        'rating'       => [ 'rating', 'integer', '', '0', undef ]
    },
    attributeCategory => {
        'attributedesc' => [ 'attributeDesc', 'varchar (128)', '', '0', undef ],
        'fmorg'         => [],
        'id'            => [ 'id',            'numeric (18)',  '', '2', undef ]
    },
    userSession => {
        'fmorg'         => [],
        'userinfo_id'   => [ 'userInfo_id', 'numeric (18)', '', '2', undef ],
        'expiredate'    => [ 'expireDate', 'timestamp', '', '0', undef ],
        'ipaddress'     => [ 'ipAddress', 'varchar (24)', '', '0', undef ],
        'md5sum'        => [ 'md5sum', 'char (32)', '', '2', undef ],
        'insertiondate' => [ 'insertionDate', 'timestamp', '', '0', undef ]
    },
    extremes => {
        'maxval'  => [ 'maxVal',  'numeric (15)', '', '0', undef ],
        'fmorg'   => [],
        'minval'  => [ 'minVal',  'numeric (15)', '', '0', undef ],
        'public'  => [],
        'name'    => [ 'name',    'varchar (32)', '', '2', undef ],
        'colname' => [ 'colName', 'varchar (64)', '', '0', undef ]
    },
    ratings_view => {
        'c.md5sum' => [ 'c.md5sum', '', '', '0', undef ],
        'a.rating' => [ 'a.rating', '', '', '0', undef ],
        'b.name'   => [ 'b.name',   '', '', '0', undef ]
    },
    whorated_view => {
        'count (*) as numratings' =>
          [ 'count (*) as numRatings', '', '', '0', undef ],
        'a.name' => [ 'a.name', '', '', '0', undef ]
    },
    users_view => {
        'name ||\'<\'|| email ||\'>\' as whoisthis' =>
          [ 'name ||\'<\'|| email ||\'>\' as whoIsThis', '', '', '0', undef ],
        'acctbalance'     => [ 'acctBalance',     '', '', '0', undef ],
        'currentcategory' => [ 'currentCategory', '', '', '0', undef ],
        'birthdate'       => [ 'birthDate',       '', '', '0', undef ],
        'active'          => [ 'active',          '', '', '0', undef ],
        'id'              => [ 'id',              '', '', '0', undef ]
    },
);


# Check that each class has of the expected atts attributes
foreach my $class (@$classes) {
  isa_ok($class, 'HASH');
  ok(exists($atts{$class->{name}})) or
	diag(q{Unexpected class name: }. $class->{name});

  # check contents
  is_deeply(
			$class->{atts},
			$atts{ $class->{name} },
			q{atts for } . $class->{name}
		   );

  # remove class from hash
  delete $atts{$class->{name}};
} 

# Expect no classes left now
cmp_ok(scalar(keys %atts), q{==}, 0, q{Expect 0 classes});

__END__

