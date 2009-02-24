#   $Id: 611-output-format-columns.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use warnings;
use strict;

use Data::Dumper;
use Test::More;
use Test::Exception;  # test code that dies
use File::Spec::Functions;
use lib catdir qw ( blib lib );

#plan tests => 9;
plan 'no_plan';

use lib q{lib};
use_ok ('Parse::Dia::SQL');
use_ok ('Parse::Dia::SQL::Output');
use_ok ('Parse::Dia::SQL::Output');

my $diasql = Parse::Dia::SQL->new(db => 'db2');
my $subclass = undef;
lives_ok( sub { $subclass = $diasql->get_output_instance(); }, q{get_output_instance (db2) should not die});
isa_ok($subclass, 'Parse::Dia::SQL::Output::DB2');

my @columns = (
  [ 'one',                        'two',         'three' ],
  [ 'her we go',,                 'again' ],
  [ 'once upon a time there was', 'three bears', 'who ..' ]
);


my @form_cols = ();
lives_ok( sub { @form_cols = $subclass->_format_columns(@columns); }, q{_format_columns should not die});

#$diasql->_format_columns()

diag("TODO: check contents of form_cols");

__END__
