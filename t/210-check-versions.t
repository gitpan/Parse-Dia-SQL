#   $Id:  $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 15;

use_ok ('Parse::Dia::SQL');

my $pds = Parse::Dia::SQL->new( file => catfile(qw(t data version.supported.dia)), db => 'db2' );
isa_ok($pds, q{Parse::Dia::SQL}, q{Expect a Parse::Dia::SQL object});

# negative tests
ok(!$pds->_check_object_version('foo', 0), q{unknown object type});
ok(!$pds->_check_object_version('', 0), q{missing object type});

# positive tests
cmp_ok($pds->_check_object_version('UML - Association', '01'), q{==}, 1, q{UML - Association 01});
cmp_ok($pds->_check_object_version('UML - Association', '02'), q{==}, 1, q{UML - Association 02});

cmp_ok($pds->_check_object_version('UML - Class', 0), q{==}, 1, q{UML - Class 0});
cmp_ok($pds->_check_object_version('UML - Component', 0), q{==}, 1, q{UML - Component 0});
cmp_ok($pds->_check_object_version('UML - Note', 0), q{==}, 1, q{UML - Note 0});
cmp_ok($pds->_check_object_version('UML - SmallPackage', 0), q{==}, 1, q{UML - SmallPackage 0});

# negative tests - unsupported verions
ok(!$pds->_check_object_version('UML - Association', 3), q{UML - Association 3});

ok(!$pds->_check_object_version('UML - Class', 1), q{UML - Class 1});
ok(!$pds->_check_object_version('UML - Component', 1), q{UML - Component 1});
ok(!$pds->_check_object_version('UML - Note', 1), q{UML - Note 1});
ok(!$pds->_check_object_version('UML - SmallPackage', 1), q{UML - SmallPackage 1});





__END__

=pod

=head1 Test of XML object versions.

List of supported object versions

    <dia:object type="UML - Association"  version="1" id="XX">
    <dia:object type="UML - Association"  version="2" id="XX">
    <dia:object type="UML - Class"        version="0" id="XX">
    <dia:object type="UML - Component"    version="0" id="XX">
    <dia:object type="UML - Note"         version="0" id="XX">
    <dia:object type="UML - SmallPackage" version="0" id="XX">

=cut


