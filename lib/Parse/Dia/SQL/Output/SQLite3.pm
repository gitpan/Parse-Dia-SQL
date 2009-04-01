package Parse::Dia::SQL::Output::SQLite3;

# $Id: SQLite3.pm,v 1.4 2009/04/01 08:01:55 aff Exp $

=pod

=head1 NAME

Parse::Dia::SQL::Output::SQLite3 - Create SQL for SQLite version 3.

=head1 SYNOPSIS

    use Parse::Dia::SQL;
    my $dia = Parse::Dia::SQL->new(...);
    print $dia->get_sql();

=head1 DESCRIPTION

This sub-class creates SQL for the SQLite database version 3.

=cut

use warnings;
use strict;

use Data::Dumper;
use File::Spec::Functions qw(catfile);

use lib q{lib};
use base q{Parse::Dia::SQL::Output};    # extends

require Parse::Dia::SQL::Logger;
require Parse::Dia::SQL::Const;

=head2 new

The constructor. 

Object names in SQLite have no inherent limit. 60 has been arbitrarily chosen.

=cut

sub new {
  my ( $class, %param ) = @_;
  my $self = {};

  # Set defaults for sqlite
  $param{db} = q{sqlite3};
  $param{object_name_max_length} = $param{object_name_max_length} || 60;

  $self = $class->SUPER::new( %param );
  bless( $self, $class );

  return $self;
}

=head2 _get_create_table_sql

Generate create table statement for a single table using SQLite
syntax:

Includes class comments before the table definition.

Includes autoupdate triggers based on the class comment.

=head3 autoupdate triggers

If the class comment includes a line like:

<autoupdate:I<foo>/>

Then an 'after update' trigger is generated for this table which
executes the statement I<foo> for the updated row.

Examples of use include tracking record modification dates
(C<<autoupdate:dtModified=datetime('now')/>>) or deriving a value from
another field (C<<autoupdate:sSoundex=soundex(sName)/>>)

=cut

sub _get_create_table_sql {

  my ( $self, $table ) = @_;
  my $sqlstr = '';
  my $temp;
  my $comment;
  my $tablename;
  my $trigger = '';
  my $update;
  my $primary_keys = '';

  # include the comments before the table creation
  $comment = $table->{comment};
  if ( !defined( $comment ) ) { $comment = ''; }
  $tablename = $table->{name};
  $sqlstr .= $self->{newline};
  if ( $comment ne "" ) {
    $temp = "-- $comment";
    $temp =~ s/\n/\n-- /g;
    $temp =~ s/^-- <autoupdate(\s*)(.*):(.*)\/>$//mgi;
    if ( $temp ne "" ) {
      if ( $temp !~ /\n$/m ) { $temp .= $self->{newline}; }
      $sqlstr .= $temp;
    }
  }

  # Call the base class to generate the main create table statements
  $sqlstr .= $self->SUPER::_get_create_table_sql( $table );

  # Generate update triggers if required
  if ( $comment =~ /<autoupdate(\s*)(.*):(.*)\/>/mi ) {
    $update  = $3;    # what we will set it to
    $trigger = $2;    # the trigger suffix to use (optional)
    $trigger = $tablename . "_autoupdate" . $trigger;

    # Check that the column exists
    foreach $temp ( @{ $table->{attList} } ) {

      # build the two primary key elements
      if ( $$temp[3] == 2 ) {
        if ( $primary_keys ) { $primary_keys .= " and "; }
        $primary_keys .= $$temp[0] . "=OLD." . $$temp[0];
      }
    }

    $sqlstr .=
        "drop trigger if exists $trigger"
      . $self->{end_of_statement}
      . $self->{newline};

    $sqlstr .=
"create trigger $trigger after update on $tablename begin update $tablename set $update where $primary_keys;end"
      . $self->{end_of_statement}
      . $self->{newline};

    $sqlstr .= $self->{newline};
  }

  return $sqlstr;
}

=head2 get_schema_drop

Generate drop table statments for all tables using SQLite syntax:

  drop table I<foo> if exists

=cut

sub get_schema_drop {
  my $self   = shift;
  my $sqlstr = '';

  return unless $self->_check_classes();

CLASS:
  foreach my $object ( @{ $self->{classes} } ) {
    next CLASS if ( $object->{type} ne q{table} );

    # Sanity checks on internal state
    if (!defined( $object )
      || ref( $object ) ne q{HASH}
      || !exists( $object->{name} ) )
    {
      $self->{log}
        ->error( q{Error in table input - cannot create drop table sql!} );
      next;
    }

    $sqlstr .=
        qq{drop table if exists }
      . $object->{name}
      . $self->{end_of_statement}
      . $self->{newline};
  }

  return $sqlstr;
}

=head2 get_view_drop

Generate drop view statments for all tables using SQLite syntax:

  drop view I<foo> if exists

=cut

# Create drop view for all views
sub get_view_drop {
  my $self   = shift;
  my $sqlstr = '';

  return unless $self->_check_classes();

CLASS:
  foreach my $object ( @{ $self->{classes} } ) {
    next CLASS if ( $object->{type} ne q{view} );

    # Sanity checks on internal state
    if (!defined( $object )
      || ref( $object ) ne q{HASH}
      || !exists( $object->{name} ) )
    {
      $self->{log}
        ->error( q{Error in table input - cannot create drop table sql!} );
      next;
    }

    $sqlstr .=
        qq{drop view if exists }
      . $object->{name}
      . $self->{end_of_statement}
      . $self->{newline};
  }

  return $sqlstr;

}

=head2 _get_fk_drop

Drop foreign key enforcement triggers using SQLite syntax:

  drop trigger I<foo> if exists
  
The automatically generated foreign key enforcement triggers are:

See L<_get_create_association_sql> for more details.

=over

=item

I<constraint_name>_bi_tr

=item

I<constraint_name>_bu_tr

=item

I<constraint_name>_buparent_tr

=item

I<constraint_name>_bdparent_tr


=back

=cut

# Drop all foreign keys
sub _get_fk_drop {
  my $self   = shift;
  my $sqlstr = '';
  my $temp;

  return unless $self->_check_associations();

  # drop fk
  foreach my $association ( @{ $self->{associations} } ) {
    my ( $table_name, $constraint_name, undef, undef, undef, undef ) =
      @{$association};

    $temp = $constraint_name . "_bi_tr";
    $sqlstr .=
        qq{drop trigger if exists $temp}
      . $self->{end_of_statement}
      . $self->{newline};

    $temp = $constraint_name . "_bu_tr";
    $sqlstr .=
        qq{drop trigger if exists $temp}
      . $self->{end_of_statement}
      . $self->{newline};

    $temp = $constraint_name . "_buparent_tr";
    $sqlstr .=
        qq{drop trigger if exists $temp}
      . $self->{end_of_statement}
      . $self->{newline};

    $temp = $constraint_name . "_bdparent_tr";
    $sqlstr .=
        qq{drop trigger if exists $temp}
      . $self->{end_of_statement}
      . $self->{newline};

    $sqlstr .= $self->{newline};

  }
  return $sqlstr;
}

=head2 _get_drop_index_sql

drop index statement using SQLite syntax:

  drop index I<foo> if exists

=cut

sub _get_drop_index_sql {
  my ( $self, $tablename, $indexname ) = @_;
  return
      qq{drop index if exists $indexname}
    . $self->{end_of_statement}
    . $self->{newline};
}

=head2 get_permissions_create

SQLite doesn't support permissions, so supress this output.

=cut

sub get_permissions_create {
  return '';
}

=head2 get_permissions_drop

SQLite doesn't support permissions, so supress this output.

=cut

sub get_permissions_drop {
  return '';
}

=head2 _get_create_association_sql

Create the foreign key enforcement triggers using SQLite syntax:

  create trigger I<fkname>[_bi_tr|_bu_tr|_bdparent_tr|_buparent_tr]

Because SQLite doesn't natively enforce foreign key constraints (see L<http://www.sqlite.org/omitted.html>), 
we use triggers to emulate this behaviour.

The trigger names are the default contraint name (something like I<parent_table>_fk_I<fk_column>) with suffixes:

=over

=item

I<constraint_name>_bi_tr

Before insert on the child table require that the parent key exists.

=item

I<constraint_name>_bu_tr

Before update on the child table require that the parent key exists.

=item

I<constraint_name>_buparent_tr

Before update on the parent table ensure that there are no dependant child records.

=item

I<constraint_name>_bdparent_tr

Default trigger: Before delete on the parent table ensure that there are no dependant child records.

If 'on delete cascade' is specified as the contraint (in the multiplicity field): 
Before delete on the parent table delete all dependant child records.


=back


=cut

# Create sql for given association.
sub _get_create_association_sql {
  my ( $self, $association ) = @_;
  my $sqlstr = '';
  my $temp;

  # Sanity checks on input
  if ( ref( $association ) ne 'ARRAY' ) {
    $self->{log}
      ->error( q{Error in association input - cannot create association sql!} );
    return;
  }

  # FK constraints are implemented as triggers in SQLite

  my (
    $table_name, $constraint_name, $key_column,
    $ref_table,  $ref_column,      $constraint_action
  ) = @{$association};

  # Shorten constraint name, if necessary (DB2 only)
  $constraint_name = $self->_create_constraint_name( $constraint_name );

  $temp = $constraint_name . "_bi_tr";
  $sqlstr .=
qq{create trigger $temp before insert on $table_name for each row begin select raise(abort, 'insert on table $table_name violates foreign key constraint $constraint_name') WHERE NEW.$key_column is not null and (select $ref_column from $ref_table where $ref_column=new.$key_column) is null;end}
    . $self->{end_of_statement}
    . $self->{newline};

  $temp = $constraint_name . "_bu_tr";
  $sqlstr .=
qq{create trigger $temp before update on $table_name for each row begin select raise(abort, 'update on table $table_name violates foreign key constraint $constraint_name') WHERE NEW.$key_column is not null and (select $ref_column from $ref_table where $ref_column=new.$key_column) is null;end}
    . $self->{end_of_statement}
    . $self->{newline};

  # note that the before delete triggers are on the parent ($ref_table)
  $temp = $constraint_name . "_bdparent_tr";
  if ( $constraint_action =~ /on delete cascade/i ) {
    $sqlstr .=
qq{create trigger $temp before delete on $ref_table for each row begin delete from $table_name where $table_name.$key_column=old.$ref_column;end}
      . $self->{end_of_statement}
      . $self->{newline};
  } else    # default on delete restrict
  {
    $sqlstr .=
qq{create trigger $temp before delete on $ref_table for each row begin select raise(abort, 'delete on table $ref_table violates foreign key constraint $constraint_name on $table_name') where (select $key_column from $table_name where $key_column=old.$ref_column) is not null;end}
      . $self->{end_of_statement}
      . $self->{newline};
  }

  # Cascade updates doesn't work, so we always restrict
  $temp = $constraint_name . "_buparent_tr";
  $sqlstr .=
qq{create trigger $temp before update on $ref_table for each row begin select raise(abort, 'update on table $ref_table violates foreign key constraint $constraint_name on $table_name') where (select $key_column from $table_name where $key_column=old.$ref_column) is not null;end}
    . $self->{end_of_statement}
    . $self->{newline};

  $sqlstr .= $self->{newline};

  return $sqlstr;
}

1;

__END__


