package Parse::Dia::SQL::Output::DB2;

# $Id: DB2.pm,v 1.1 2009/02/23 07:36:17 aff Exp $
=pod

=head1 NAME

Parse::Dia::SQL::Output::DB2 - SQL formatter class for DB2.

=head1 SYNOPSIS

    use Parse::Dia::SQL;
    my $dia = Parse::Dia::SQL->new(...);
    my $output = $dia->get_output_instance();
    print $output->get_sql();

=head1 DESCRIPTION


=cut


use warnings;
use strict;

use Data::Dumper;
use File::Spec::Functions qw(catfile);

use lib q{lib};
use base q{Parse::Dia::SQL::Output}; # extends

require Parse::Dia::SQL::Logger;
require Parse::Dia::SQL::Const;

=head2 new

The constructor.  Arguments:

=cut

sub new {
  my ( $class, %param ) = @_;
  my $self = {};

  # Set defaults for db2
  $param{object_name_max_length} = $param{object_name_max_length} || 18;
  $param{index_options} = ['allow reverse scans'] unless 
    defined($param{index_options}) && scalar(@{$param{index_options}});
  $param{db} = q{db2}; 

  $self = $class->SUPER::new(%param);

  bless( $self, $class );
  return $self;
}

=head2

Create primary key clause, e.g.

constraint pk_<tablename> primary key (<column1>,..,<columnN>)

For DB2 the PK must be 18 characters or less

=cut


sub _create_pk_string {
  my ($self, $tablename, @pks) = @_;

	if (!$tablename) {
		$self->{log}->error(q{Missing argument tablename - cannot create pk string!});
		return;
	}

  # old school name length reduction
  $tablename = $self->{utils}->mangle_name ($tablename, $self->{object_name_max_length} - 4);

  # new school name length reduction
#  $tablename = $self->{utils}->make_name ($tablename);

  return qq{constraint pk_$tablename primary key (} .
			join(q{,}, @pks)
		   .q{)};
}




1;

__END__

=pod

Subclass for outputting SQL for the DB2 database

=cut
