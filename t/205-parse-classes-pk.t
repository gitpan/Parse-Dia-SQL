#   $Id: 205-parse-classes-pk.t,v 1.1 2009/02/23 07:36:17 aff Exp $

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

# Hash with class/view names as keys and primary key as (hashref) elements
my %pk = (
    imageInfo => [ [ 'id', 'numeric (18)', '', '2', undef ] ],
    subImageInfo => [
        [ 'imageInfo_id', 'numeric (18)', '', '2', undef ],
        [ 'pixSize',      'integer',      '', '2', undef ]
    ],
    imageCategoryList => [
        [ 'imageInfo_id', 'numeric (18)', '', '2', undef ],
        [ 'name',         'varchar (32)', '', '2', undef ]
    ],
    categoryNames => [ [ 'name', 'varchar (32)', '', '2', undef ] ],
    imageAttribute => [
        [ 'imageInfo_id',         'numeric (18)', '', '2', undef ],
        [ 'attributeCategory_id', 'numeric (18)', '', '2', undef ]
    ],
    userInfo => [ [ 'id', 'numeric (18)', '', '2', undef ] ],
    userAttribute => [
        [ 'userInfo_id',          'numeric (18)', '', '2', undef ],
        [ 'attributeCategory_id', 'numeric (18)', '', '2', undef ]
    ],
    userImageRating => [
        [ 'userInfo_id',  'numeric (18)', '', '2', undef ],
        [ 'imageInfo_id', 'numeric (15)', '', '2', undef ]
    ],
    attributeCategory => [ [ 'id', 'numeric (18)', '', '2', undef ] ],
    userSession => [
        [ 'userInfo_id', 'numeric (18)', '', '2', undef ],
        [ 'md5sum',      'char (32)',    '', '2', undef ]
    ],
    extremes => [ [ 'name', 'varchar (32)', '', '2', undef ] ],
    ratings_view  => [],
    whorated_view => [],
    users_view    => [],
);


# Check that each class has of the expected pk attributes
foreach my $class (@$classes) {
  isa_ok($class, 'HASH');
  ok(exists($pk{$class->{name}})) or
	diag(q{Unexpected class name: }. $class->{name});

  #diag($class->{name} . ' pk :' . Dumper($class->{pk}));

  # check contents
   is_deeply(
 			$class->{pk},
 			$pk{ $class->{name} },
 			q{pk for } . $class->{name}
 		   );

  # remove class from hash
  delete $pk{$class->{name}};
} 

# Expect no classes left now
cmp_ok(scalar(keys %pk), q{==}, 0, q{Expect 0 classes left});

__END__

