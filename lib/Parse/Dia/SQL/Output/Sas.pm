package Parse::Dia::SQL::Output::Sas;

# $Id: Sas.pm,v 1.2 2009/02/24 09:58:24 aff Exp $

=pod

=head1 NAME 

Sas.pm - Create SQL for Sas.

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

  # Set defaults for sas
  $param{db} = q{sas}; 
  $param{object_name_max_length} = $param{object_name_max_length} || 32;

  $self = $class->SUPER::new(%param);
  bless( $self, $class );

  return $self;
}


1;

__END__

