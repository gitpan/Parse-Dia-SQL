package Parse::Dia::SQL::Logger;

# $Id: Logger.pm,v 1.6 2009/03/13 14:17:23 aff Exp $

=pod

=head1 NAME

Parse::Dia::SQL::Logger - Wrapper for Log::Log4perl

=head1 SYNOPSIS

    use Parse::Dia::SQL::Logger;
    my $logger = Parse::Dia::SQL::Logger::->new();
    my $log = $logger->get_logger(__PACKAGE__);
    $log->error('error');
    $log->info('info');

=head1 DESCRIPTION

This module is a wrapper around Log::Log4perl. 

=head1 SEE ALSO

  Log::Log4perl

Make appender_thresholds_adjust return number of appenders changed:

  https://rt.cpan.org/Ticket/Display.html?id=43426

=cut

use warnings;
use strict;

use Log::Log4perl;
use Log::Dispatch::FileRotate;

use constant APPENDER_THRESHOLDS_ADJUST_LOGOFF =>  7;
use constant APPENDER_THRESHOLDS_ADJUST_LOGON  => -7;

=head2 new

The constructor.

=cut

sub new {
  my ( $class, %param ) = @_;

  my $self = {
    log         => undef,
  };

  bless( $self, $class );

  $self->_init_log();
  return $self;
}

# Initialize the logger.  The commented lines are deliberately left to
# serve as exmples.
sub _init_log {
  my $self = shift;

  # Init logging
  my $conf = q(
    # Main logger for Parse::Dia::SQL
#    log4perl.category.Parse::Dia::SQL        = INFO, file, screen-main
#    log4perl.category.Parse::Dia::SQL        = DEBUG, file, screen-main
#    log4perl.category.Parse::Dia::SQL        = WARN, screen-main
#    log4perl.category.Parse::Dia::SQL        = DEBUG, screen-main
    log4perl.category.Parse::Dia::SQL        = INFO, screen-main
    log4perl.appender.screen-main         = Log::Log4perl::Appender::Screen
    log4perl.appender.screen-main.stderr  = 1
    log4perl.appender.screen-main.layout  = PatternLayout
    log4perl.appender.screen-main.layout.ConversionPattern=[%p] %m%n 

    log4perl.appender.file           = Log::Dispatch::FileRotate
    log4perl.appender.file.filename  = dia-sql.log
    log4perl.appender.file.mode      = append
    log4perl.appender.file.size      = 100000
    log4perl.appender.file.max       = 5
    log4perl.appender.file.layout    = PatternLayout
    log4perl.appender.file.layout.ConversionPattern=[%p] %d %F:%L: %m%n


    # Separate logger for Output::*
#    log4perl.category.Parse::Dia::SQL::Output  = DEBUG, screen-output
    log4perl.category.Parse::Dia::SQL::Output  = INFO, screen-output
    log4perl.appender.screen-output            = Log::Log4perl::Appender::Screen
    log4perl.appender.screen-output.stderr     = 1
    log4perl.appender.screen-output.layout     = PatternLayout
    log4perl.appender.screen-output.layout.ConversionPattern=[%p] %m%n 
    log4perl.additivity.Parse::Dia::SQL::Output  = 0

    # Separate logger for Utils.pm
#    log4perl.category.Parse::Dia::SQL::Utils  = DEBUG, screen-utils
    log4perl.category.Parse::Dia::SQL::Utils  = INFO, screen-utils
    log4perl.appender.screen-utils            = Log::Log4perl::Appender::Screen
    log4perl.appender.screen-utils.stderr     = 1
    log4perl.appender.screen-utils.layout     = PatternLayout
    log4perl.appender.screen-utils.layout.ConversionPattern=[%p] %m%n 
    log4perl.additivity.Parse::Dia::SQL::Utils  = 0

  );
  
  Log::Log4perl::init( \$conf );

  # Adjust call stack for caller class, see man Log::Log4perl
  $Log::Log4perl::caller_depth = 1;
    
  return 1;
}

=head2 get_logger

  Return logger singleton object.

=cut

sub get_logger {
    my ($self, $name) = @_;
    #return $self->{logger};
    return Log::Log4perl::->get_logger($name);
}


=head2 log_off

Decrease log level on all appenders.
1    
=cut

sub log_off {
  my $self = shift;

  # Make sure it works also in case this is
  # called as function before object is blessed.
  _init_log() if ( !Log::Log4perl->initialized() );

  Log::Log4perl->appender_thresholds_adjust(APPENDER_THRESHOLDS_ADJUST_LOGOFF);

  return 1;
}

=head2 log_on

Increase log level on all appenders.
    
=cut

sub log_on {
  my $self = shift;

  # Make sure it works also in case this is
  # called as function before object is blessed.
  _init_log() if ( !Log::Log4perl->initialized() );

  Log::Log4perl->appender_thresholds_adjust(APPENDER_THRESHOLDS_ADJUST_LOGON);

  return 1;
}


1;

__END__

# End of Parse::Dia::SQL::Logger

