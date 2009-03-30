#   $Id: 612-output-get-comment.t,v 1.4 2009/03/30 11:46:07 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;  # test code that dies
use File::Spec::Functions;
use lib catdir qw ( blib lib );

plan tests => 5;

use lib q{lib};
use_ok ('Parse::Dia::SQL');
use_ok ('Parse::Dia::SQL::Output');

my $diasql = Parse::Dia::SQL->new(db => 'db2');
$diasql->{converted} = 1; # Fool Parse::Dia::SQL into thinking convert() was called
$diasql->{files} = ['foo.dia','bar.dia','tze.dia'];
 
my $subclass = undef;
lives_ok( sub { $subclass = $diasql->get_output_instance(); }, q{get_output_instance (db2) should not die});
isa_ok($subclass, 'Parse::Dia::SQL::Output::DB2');

my $comment = undef;
lives_ok( sub { $comment = $subclass->_get_comment(); }, q{_get_comment should not die});

#diag($subclass->_get_comment());
diag("TODO: check contents of gc");

__END__
