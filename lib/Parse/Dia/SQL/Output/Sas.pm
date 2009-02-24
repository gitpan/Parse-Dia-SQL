package Parse::Dia::SQL::Output::Sas;

# $Id: Sas.pm,v 1.1 2009/02/23 07:36:17 aff Exp $

=pod

=head1 NAME 

Informix.pm - Create SQL for Informix.

=head1 SEE ALSO

 Parse::Dia::SQL::Output

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

  # Set defaults for informix
  $param{db} = q{informix}; 
  $param{object_name_max_length} = $param{object_name_max_length} || 30;

  $self = $class->SUPER::new(%param);
  bless( $self, $class );

  return $self;
}


=head2 _get_drop_index_sql

Create drop index sql for given index. Discard tablename.

(same as postgres)

=cut

sub _get_drop_index_sql {
  my ( $self, $tablename, $indexname ) = @_;
  return qq{drop index $indexname cascade}
    . $self->{end_of_statement}
    . $self->{newline};
}

1;

__END__

