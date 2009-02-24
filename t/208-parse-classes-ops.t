#   $Id: 208-parse-classes-ops.t,v 1.1 2009/02/23 07:36:17 aff Exp $

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

# Hash with class/view names as keys and operations (if any) as
# (hashref) elements
my %ops = (
    imageInfo => [
        [ 'idx_iimd5', 'unique index', [ 'md5sum' ], '', undef ],
        [ 'idx_iiid',  'index',        [ 'id' ],     '', undef ],
        [ 'all',       'grant',        [ 'fmorg' ],  '', undef ],
        [ 'select',    'grant',        [ 'public' ], '', undef ]
    ],
    subImageInfo => [
        [ 'idx_siiid', 'index', [ 'imageInfo_id' ], '', undef ],
        [ 'idx_siips', 'index', [ 'pixSize' ],      '', undef ],
        [ 'all',       'grant', [ 'fmorg' ],        '', undef ]
    ],
    imageCategoryList => [
        [ 'idx_iclidnm', 'index', [ 'imageInfo_id', 'name' ], '', undef ],
        [ 'all', 'grant', [ 'fmorg' ], '', undef ]
    ],
    categoryNames => [
        [ 'select', 'grant', [ 'public' ], '', undef ],
        [ 'all',    'grant', [ 'fmorg' ],  '', undef ]
    ],
    imageAttribute => [ [ 'all', 'grant', [ 'fmorg' ], '', undef ] ],
    userInfo => [
        [ 'idx_uinm', 'unique index', [ 'name', 'md5sum' ], '', undef ],
        [ 'idx_uiid', 'index', [ 'id' ],    '', undef ],
        [ 'all',      'grant', [ 'fmorg' ], '', undef ]
    ],
    userAttribute => [
        [ 'idx_uauiid', 'index', [ 'userInfo_id' ], '', undef ],
        [ 'all',        'grant', [ 'fmorg' ],       '', undef ]
    ],
    userImageRating => [
        [ 'idx_uiruid', 'index', [ 'userInfo_id' ], '', undef ],
        [ 'all',        'grant', [ 'fmorg' ],       '', undef ]
    ],
    attributeCategory => [
        [ 'idx_acid', 'index', [ 'id' ],    '', undef ],
        [ 'all',      'grant', [ 'fmorg' ], '', undef ]
    ],
    userSession => [
        [ 'idx_usmd5', 'index', [ 'md5sum' ], '', undef ],
        [ 'all',       'grant', [ 'fmorg' ],  '', undef ]
    ],
    extremes => [
        [ 'select', 'grant', [ 'public' ], '', undef ],
        [ 'all',    'grant', [ 'fmorg' ],  '', undef ]
    ],
    ratings_view => [
        [ 'userImageRating a',                     'from',     [], '', undef ],
        [ 'userImageRating z',                     'from',     [], '', undef ],
        [ 'userInfo b',                            'from',     [], '', undef ],
        [ 'imageInfo c',                           'from',     [], '', undef ],
        [ '(((a.userInfo_id = b.id)',              'where',    [], '', undef ],
        [ 'and (a.imageInfo_id = c.id)',           'where',    [], '', undef ],
        [ 'and (a.userInfo_id = z.userInfo_id))',  'where',    [], '', undef ],
        [ 'and (a.userInfo_id <> z.userInfo_id))', 'where',    [], '', undef ],
        [ 'c.md5sum,b.name,a.rating',              'order by', [], '', undef ]
    ],
    whorated_view => [
        [ 'userInfo a',             'from',     [], '', undef ],
        [ 'userImageRating b',      'from',     [], '', undef ],
        [ '(a.id = b.userInfo_id)', 'where',    [], '', undef ],
        [ 'a.name',                 'group by', [], '', undef ]
    ],
    users_view => [
        [ 'userInfo',      'from',     [], '', undef ],
        [ 'userInfo.name', 'order by', [], '', undef ]
    ],
);


# Check that each class has of the expected ops attributes
foreach my $class (@$classes) {
  isa_ok($class, 'HASH');
  ok(exists($ops{$class->{name}})) or
	diag($class->{name} . ' ops :' . Dumper($class->{ops}));

  # check contents
  is_deeply(
 			$class->{ops},
 			$ops{ $class->{name} },
 			q{ops for } . $class->{name}
 		   );

  # remove class from hash
  delete $ops{$class->{name}};
} 

# Expect no classes left now
cmp_ok(scalar(keys %ops), q{==}, 0, q{Expect 0 classes left});

__END__

