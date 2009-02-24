package Parse::Dia::SQL::Output;

# $Id: Output.pm,v 1.3 2009/02/24 05:43:39 aff Exp $

=pod

=head1 NAME

Parse::Dia::SQL::Output - Base sql formatter class.

=head1 SYNOPSIS

    use Parse::Dia::SQL;
    my $dia = Parse::Dia::SQL->new(...);
    my $output = $dia->get_output_instance();
    print $output->get_sql();

=head1 DESCRIPTION

This is the base sql formatter class for creating sql. It contains
basic functionality, which can be overridden in subclasses, one for
each RDBMS.

=head1 SEE ALSO

  Parse::Dia::SQL::Output::DB2
  Parse::Dia::SQL::Output::Oracle

=cut


use warnings;
use strict;

use Text::Table;
use Data::Dumper;
use Config;

use lib q{lib};
use Parse::Dia::SQL::Utils;
use Parse::Dia::SQL::Logger;
use Parse::Dia::SQL::Const;

=head2 new

The constructor.  Arguments:

  db    - the target database type

=cut

sub new {
  my ( $class, %param ) = @_;

  my $self = {

    # command line options
    files       => $param{files}       || [],       # dia files
    db          => $param{db}          || undef,
    uml         => $param{uml}         || undef,
    fk_auto_gen => $param{fk_auto_gen} || undef,
    pk_auto_gen => $param{pk_auto_gen} || undef,
    default_pk  => $param{default_pk}  || undef,    # opt_p

    # formatting options
    indent           => $param{indent}           || q{ } x 3,
    newline          => $param{newline}          || "\n",
    end_of_statement => $param{end_of_statement} || ";",
    column_separator => $param{column_separator} || ",",
    sql_comment      => $param{sql_comment}      || "-- ",

    # sql options
    index_options => $param{index_options} || [],
    object_name_max_length => $param{object_name_max_length}
      || undef,

		# parsed datastructures
    associations   => $param{associations}   || [],    # foreign keys, indices
    classes        => $param{classes}        || [],    # tables and views
    components     => $param{components}     || [],    # insert statements
    small_packages => $param{small_packages} || [],

    # references to components
    log   => undef,
    const => undef,
    utils => undef,
  };

  bless($self, $class);

  $self->_init_log();
  $self->_init_const();
  $self->_init_utils();

  return $self;
}


=head2 _init_log

Initialize logger

=cut 

sub _init_log {
  my $self = shift;

  my $logger = Parse::Dia::SQL::Logger::->new();
  $self->{log} = $logger->get_logger(__PACKAGE__);
  return 1;
}

=head2 _init_const

Initialize Constants component

=cut 

sub _init_const {
  my $self = shift;
  $self->{const} = Parse::Dia::SQL::Const::->new();
  return 1;
}

=head2 _init_utils

Initialize Parse::Dia::SQL::Utils class.

=cut

sub _init_utils {
  my $self = shift;
  $self->{utils} = Parse::Dia::SQL::Utils::->new(db => $self->{db});
  return 1;
}

=head2 get_comment

Return string with comment containing target database, $VERSION, time
and list of files etc.

=cut

sub _get_comment {
  my $self = shift;
  my $files_word =
    (scalar(@{ $self->{files} }) == 1)
    ? q{Input File:       }
    : q{Input Files:      };

  return 
      $self->{sql_comment}
    . qq{Environment:      }
    . qq{Perl $], $^X, $Config{archname}}
    . $self->{newline}
    . $self->{sql_comment}
    . qq{Target Database:  }
    . $self->{db}
    . $self->{newline}
    . $self->{sql_comment}
    . qq{SQL::Dia version: }
    . $Parse::Dia::SQL::VERSION
    . $self->{newline}
    . $self->{sql_comment}
    . qq{Generated at:     }
    . scalar localtime()
    . $self->{newline}
    . $self->{sql_comment}
    . $files_word
    . join( q{,}, @{$self->{files}} )
    . $self->{newline}
    . $self->{newline};
}

=head2 get_sql

Return all sql

=cut

sub get_sql {
  my $self = shift;

  #   -- Generated SQL Constraints Drop statements
  #   -- Generated Permissions Drops
  #   -- Generated SQL View Drop Statements
  #   -- Generated SQL Schema Drop statements
  #   -- Generated SQL Schema
  #   -- Generated SQL Views
  #   -- Generated Permissions
  #   -- Generated SQL Insert statements
  #   -- Generated SQL Constraints

  ## No critic (NoWarnings)
	no warnings q{uninitialized};
  return
	  $self->_get_comment()
    . $self->{newline}
    . $self->get_constraints_drop()
    . $self->{newline}
    . $self->get_permissions_drop()
    . $self->{newline}
    . $self->get_view_drop()
    . $self->{newline}
    . $self->get_schema_drop()
    . $self->{newline}
    . $self->get_schema_create()
    . $self->{newline}
    . $self->get_view_create()
    . $self->{newline}
    . $self->get_permissions_create()
    . $self->{newline}
    . $self->get_inserts()
    . $self->{newline}
    . $self->get_associations_create();
}

=head2 get_inserts

Return insert statements. These are based on content of the
I<components>, and split on the linefeed character ("\n").

Add $self->{end_of_statement} to each statement.

=cut

sub get_inserts {
  my $self   = shift;
  my $sqlstr = '';

	# Expect array ref of hash refs
  return unless $self->_check_components();

	$self->{log}->debug( Dumper($self->{components}))
		if $self->{log}->is_debug;

  foreach my $component ( @{ $self->{components} } ) {
    foreach my $vals ( split( "\n", $component->{text} ) ) {


      $sqlstr .=
          qq{insert into }
        . $component->{name}
        . qq{ values($vals) }
				. $self->{end_of_statement}
        . $self->{newline};
    }
  }

  return $sqlstr;
}

=head2 get_constraints_drop

drop all constraints (e.g. foreign keys and indices)

This sub is split into two parts to make it easy sub subclass either.

=cut

sub get_constraints_drop {
  my $self   = shift;

  return 
		$self->_get_fk_drop() . 
		$self->_get_index_drop();
}

=head2 _get_fk_drop

drop all foreign keys

=cut

sub _get_fk_drop {
  my $self   = shift;
  my $sqlstr = '';

  return unless $self->_check_associations();

	# drop fk
  foreach my $association ( @{ $self->{associations} } ) {
    my ( $table_name, $constraint_name, undef, undef, undef, undef ) =
      @{$association};

    $sqlstr .=
        qq{alter table $table_name drop constraint $constraint_name }
      . $self->{end_of_statement}
      . $self->{newline};
  }
  return $sqlstr;
}


=head2 _get_index_drop

drop all indices

=cut

sub _get_index_drop {
  my $self   = shift;
	my $sqlstr = q{};

  return unless $self->_check_classes();

	# drop index
	foreach my $table (@{$self->{classes}}) {

		foreach my $operation ( @{ $table->{ops} }) {

			if (ref($operation) ne 'ARRAY') {
				$self->{log}->error( q{Error in ops input - expect an ARRAY ref, got } . ref($operation));
				next OPERATION;
			}

			my ($opname,$optype) = ($operation->[0], $operation->[1]);

			# 2nd element can be index, unique index, grant, etc
			next if ($optype !~ qr/^(unique )?index$/i);  

			$sqlstr .= $self->_get_drop_index_sql($table->{name}, $opname);
		}
	}
  return $sqlstr;
}




=head2 _get_drop_index_sql

create drop index for index on table with given name.  Note that the
tablename is not used here, but many of the overriding subclasses use
it, so we include both the tablename and the indexname as arguments to
keep the interface consistent.

=cut

sub _get_drop_index_sql {
  my ( $self, $tablename, $indexname ) = @_;
  return qq{drop index $indexname}
    . $self->{end_of_statement}
    . $self->{newline};
}


# sub get_special_pre  {}

=head2 get_view_drop

create drop view for all views

=cut

sub get_view_drop {
  my $self   = shift;  
  my $sqlstr = '';

	return unless $self->_check_classes();

 CLASS:
  foreach my $object (@{ $self->{classes} }) {
		next CLASS if ($object->{type} ne q{view});

		# Sanity checks on internal state
		if (!defined($object) || ref($object) ne q{HASH} || !exists( $object->{name} )) {
			$self->{log}->error( q{Error in table input - cannot create drop table sql!} );
			next;
		}

		$sqlstr .= qq{drop view }
    . $object->{name}
    . $self->{end_of_statement}
    . $self->{newline};
  }

  return $sqlstr;

}

=head2 _check_components

Sanity check on internal state.

Return true if and only if

  $self->{components} should be a defined array ref with 1 or more
  hash ref elements having two keys 'name' and 'text'

otherwise false.

=cut


sub _check_components {
  my $self   = shift;
  # Sanity checks on internal state
  if (!defined($self->{components})) {
    $self->{log}->warn(q{no components in schema});
    return;
  } elsif (ref($self->{components}) ne 'ARRAY') {
    $self->{log}->warn(q{components is not an ARRAY ref});
    return;
  } elsif (scalar(@{ $self->{components} } == 0)) {
    $self->{log}->warn(q{components is an empty ARRAY ref});
    return;  
  }

	foreach my $comp (@{ $self->{components} }) {
		if (ref($comp) ne q{HASH}) {
			$self->{log}->warn(q{component element must be a HASH ref});
			return;  				
		}
		if (!exists($comp->{text}) || 
			  !exists($comp->{name})) {	
			$self->{log}->warn(q{component element must be a HASH ref with elements 'text' and 'name'});
			return;  		
		}
	}

	return 1;
}


=head2 _check_classes

Sanity check on internal state.

Return true if and only if

  $self->{classes} should be a defined array ref with 1 or more elements

=cut


sub _check_classes {
  my $self   = shift;
  # Sanity checks on internal state
  if (!defined($self->{classes})) {
    $self->{log}->warn(q{no classes in schema});
    return;
  } elsif (ref($self->{classes}) ne 'ARRAY') {
    $self->{log}->warn(q{classes is not an ARRAY ref});
    return;
  } elsif (scalar(@{ $self->{classes} } == 0)) {
    $self->{log}->warn(q{classes is an empty ARRAY ref});
    return;
  }

	return 1;
}

=head2 _check_associations

Sanity check on internal state.

Return true if and only if

  $self->{associations} should be a defined array ref with 1 or more elements

otherwise false.

=cut


sub _check_associations {
  my $self   = shift;
  # Sanity checks on internal state
  if (!defined($self->{associations})) {
    $self->{log}->warn(q{no associations in schema});
    return;
  } elsif (ref($self->{associations}) ne 'ARRAY') {
    $self->{log}->warn(q{associations is not an ARRAY ref});
    return;
  } elsif (scalar(@{ $self->{associations} } == 0)) {
    $self->{log}->warn(q{associations is an empty ARRAY ref});
    return;
  }


	return 1;
}

=head2 _check_attlist

Sanity check on given reference.

Return true if and only if

  $arg should be a defined hash ref with 1 or more elements
  $arg->{name} exists and is a defined scalar
  $arg->{attList} exists and is a defined array ref.

otherwise false.

=cut

sub _check_attlist {
  my $self = shift;
  my $arg  = shift;

  # Sanity checks on internal state
  if ( !defined($arg) || ref($arg) ne q{HASH} || !exists( $arg->{name} ) ) {
    $self->{log}->error(q{Error in ref input!});
    return;
  }
  if ( !exists( $arg->{attList} ) || ref( $arg->{attList} ) ne 'ARRAY' ) {
    $self->{log}->error(q{Error in ref attList input!});
    return;
  }
  return 1;
}

=head2 get_schema_drop

create drop table for all tables

TODO: Consider rename to get_table[s]_drop

=cut

sub get_schema_drop {
  my $self   = shift;
  my $sqlstr = '';

	return unless $self->_check_classes();

 CLASS:
  foreach my $object (@{ $self->{classes} }) {
		next CLASS if ($object->{type} ne q{table});

		# Sanity checks on internal state
		if (!defined($object) || ref($object) ne q{HASH} || !exists( $object->{name} )) {
			$self->{log}->error( q{Error in table input - cannot create drop table sql!} );
			next;
		}

		$sqlstr .= qq{drop table }
    . $object->{name}
    . $self->{end_of_statement}
    . $self->{newline};
  }

  return $sqlstr;

}

=head2 get_permissions_drop

Create revoke sql

=cut

sub get_permissions_drop {
  my $self   = shift;
  my $sqlstr = '';

	# Check classes 
	return unless $self->_check_classes();
	
	# loop through classes looking for grants
	foreach my $table (@{$self->{classes}}) {

		foreach my $operation ( @{ $table->{ops} }) {

			if (ref($operation) ne 'ARRAY') {
				$self->{log}->error( q{Error in ops input - expect an ARRAY ref, got } . ref($operation));
				next OPERATION;
			}

			my ($opname,$optype,$colref) = ($operation->[0],$operation->[1],$operation->[2]);

			# 2nd element can be index, unique index, grant, etc
			next if ($optype ne q{grant});  

			$sqlstr .= 
				qq{revoke $opname on } . $table->{name} . q{ from }
					. join(q{,},@{$colref})
						. $self->{end_of_statement}
							. $self->{newline};
		}
	}

  return $sqlstr;

}

=head2 get_permissions_create

Create grant sql

=cut

sub get_permissions_create {
  my $self   = shift;
  my $sqlstr = '';

	# Check classes 
	return unless $self->_check_classes();
	
	# loop through classes looking for grants
	foreach my $table (@{$self->{classes}}) {

		foreach my $operation ( @{ $table->{ops} }) {

			if (ref($operation) ne 'ARRAY') {
				$self->{log}->error( q{Error in ops input - expect an ARRAY ref, got } . ref($operation));
				next OPERATION;
			}

			my ($opname,$optype,$colref) = ($operation->[0],$operation->[1],$operation->[2]);

			# 2nd element can be index, unique index, grant, etc
			next if ($optype ne q{grant});  

			$sqlstr .= 
				qq{$optype $opname on } . $table->{name} . q{ to }
					. join(q{,},@{$colref})
						. $self->{end_of_statement}
							. $self->{newline};
		}
	}

  return $sqlstr;
}

=head2 get_associations_create

create associations statements:

This includes the following elements

  - foreign key
  - index
  - unique index

=cut

sub get_associations_create {
  my $self   = shift;
  my $sqlstr = '';

	# Check both ass. (fk) and classes (index)
	return unless $self->_check_associations();
	return unless $self->_check_classes();
	
	# foreign key
  foreach my $object (@{ $self->{associations} }) {
		$sqlstr .= $self->_get_create_association_sql($object);
  }

	# index
  foreach my $object (@{ $self->{classes} }) {
		$sqlstr .= $self->_get_create_index_sql($object);
  }

  return $sqlstr;
}

=head2 get_schema_create

create table statements

=cut

sub get_schema_create {
  my $self   = shift;
  my $sqlstr = '';

	return unless $self->_check_classes();

 CLASS:
  foreach my $object (@{ $self->{classes} }) {
		next CLASS if ($object->{type} ne q{table});
		$sqlstr .= $self->_get_create_table_sql($object);
  }

  return $sqlstr;
}

=head2 get_view_create

create view statements

=cut

sub get_view_create {
  my $self   = shift;
  my $sqlstr = '';

	return unless $self->_check_classes();

 VIEW:
  foreach my $object (@{ $self->{classes} }) {
		next VIEW if ($object->{type} ne q{view});
		$sqlstr .= $self->_get_create_view_sql($object);
  }

  return $sqlstr;
}


=head2 _create_pk_string

Create primary key clause, e.g.

  constraint pk_<tablename> primary key (<column1>,..,<columnN>)

=cut

sub _create_pk_string {
  my ($self, $tablename, @pks) = @_;

	if (!$tablename) {
		$self->{log}->error(q{Missing argument tablename - cannot create pk string!});
		return;
	}
  
  return qq{constraint pk_$tablename primary key (} .
			join(q{,}, @pks)
		   .q{)};
}

=head2 _get_create_table_sql

Create sql for given table

=cut 

sub _get_create_table_sql {
  my ( $self, $table ) = @_;
  my @columns      = ();
  my @primary_keys = ();

	# Sanity checks on table ref
	return unless $self->_check_attlist($table);

  # Check not null and primary key property for each column. Column
  # visibility is given in $columns[3]. A value of 2 in this field
  # signifies a primary key (which also must be defined as 'not null'.
  foreach my $column ( @{ $table->{attList} } ) {

		if (ref($column) ne 'ARRAY') {
			$self->{log}->error( q{Error in view attList input - expect an ARRAY ref!} );
			next COLUMN;
		}

    # Don't warn on uninitialized values here since there are lots
    # of them.

    ## no critic (ProhibitNoWarnings)
    no warnings q{uninitialized};

    $self->{log}->debug( "column before: " . join( q{,}, @$column ) );

    # Field sequence:
    my ( $col_name, $col_type, $col_val, $col_vis, $col_com ) = @$column;

    # Add 'not null' if field is primary key
    if ( $col_vis == 2 ) {
	  $col_val = 'not null';
	}  

    # Add column name to list of primary keys if $col_vis == 2
    push @primary_keys, $col_name if ( $col_vis == 2 );

    # Add 'default' keyword to defined values different from (not)
    # null when the column is not a primary key:
    # TODO: Special handling for SAS (in subclass)
    if ( $col_val ne q{} && $col_val !~ /^(not )?null$/i && $col_vis != 2 ) {
      $col_val     = qq{ default $col_val};
    }
	
    $self->{log}->debug( "column after : "
        . join( q{,}, $col_name, $col_type, $col_val, $col_com )
    );
    push @columns,
      [$col_name, $col_type, $col_val, $col_com];
  }
  $self->{log}->warn("No columns in table") if !scalar @columns;

	# Format columns nicely
	@columns = $self->_format_columns(@columns);

  return qq{create table }
    . $table->{name} . " ("
    . $self->{newline}
    . $self->{indent}
    . join( $self->{column_separator} . $self->{newline} . $self->{indent},
    @columns, $self->_create_pk_string( $table->{name}, @primary_keys ) )
    . $self->{newline} . ")"
    . $self->{end_of_statement}
    . $self->{newline};
}

=head2 _format_columns

	Format columns in tabular form using Text::Table.

 Input:  arrayref of arrayrefs
 Output: arrayref of arrayrefs

=cut 

sub _format_columns {
  my ( $self, @columns ) = @_;
	my @columns_out = ();

  $self->{log}->debug("input: " . Dumper(\@columns)) if $self->{log}->is_debug();

  my $tb = Text::Table->new();
  $tb->load( @columns );

	# Take out one by one the formatted columns, remove newline character
	push @columns_out, map { s/\n//g; $_ } $tb->body($_) for (0 .. $tb->body_height());

  $self->{log}->debug("output: " . Dumper(@columns_out)) if $self->{log}->is_debug();
	return @columns_out;
}


=head2 _get_create_view_sql

Create sql for given view.

Similar to _get_create_table_sql, but must handle 
  'from', 
  'where',
  'order by', 
  'group by',

TODO: ADD support for 'having' clause.

=cut 

sub _get_create_view_sql {
  my ($self, $view) = @_;
  my @columns = ();
  my @from    = ();
  my @where   = ();
	my @orderby = ();
	my @groupby = ();

	# Sanity checks on view ref
	return unless $self->_check_attlist($view);

  COLUMN:
  foreach my $column ( @{ $view->{attList} } ) {
		$self->{log}->debug(q{column: }.Dumper($column));

		if (ref($column) ne 'ARRAY') {
			$self->{log}->error( q{Error in view attList input - expect an ARRAY ref, got } . ref($column));
			next COLUMN;
		}

		my $col_name = $column->[0]; # Pick first column
		$self->{log}->debug(qq{col_name: $col_name});

    push @columns,
      join( q{ }, $col_name )
      ;    # TODO: remove trailing whitespace
  }

  OPERATION:
  foreach my $operation ( @{ $view->{ops} } ) {
		$self->{log}->debug($view->{name} . q{: operation: }.Dumper($operation));

		if (ref($operation) ne 'ARRAY') {
			$self->{log}->error( q{Error in view attList input - expect an ARRAY ref, got } . ref($operation));
			next OPERATION;
		}
		
		my ($opname,$optype) = ($operation->[0],$operation->[1]);

		# skip grants
		next OPERATION if $optype eq q{grant};
		if ($optype eq q{from}) {
			push @from, $opname; 
		} elsif ($optype eq q{where}) {
			push @where, $opname; 
		} elsif ($optype eq q{order by}) {
			push @orderby, $opname; 
		} elsif ($optype eq q{group by}) {
			push @groupby, $opname; 
		} else {
			# unsupported view operation type
			$self->{log}->warn( qq{ unsupported view operation type '$optype'});
		}
	}


  my $retval = qq{create view }
    . $view->{name} . q{ as select }
    . $self->{newline}
    . $self->{indent}
    . join( $self->{column_separator} , @columns )
    . $self->{newline}
    . $self->{indent}
    . q{ from }
    . join( $self->{column_separator} , @from )
    . $self->{newline}
    . $self->{indent};

  # optional values
  $retval .=
      q{ where }
    . join( $self->{newline} . $self->{indent}, @where )
    . $self->{newline}
    . $self->{indent}
      if (scalar(@where));
  $retval .= 
      q{ group by }
    . join( $self->{column_separator} , @groupby )
      if (scalar(@groupby));
  $retval .= 
      q{ order by }
    . join( $self->{column_separator} , @orderby )
      if (scalar(@orderby));

  # add semi colon or equivalent
  $retval .=
      $self->{end_of_statement}
    . $self->{newline};
	if ($self->{log}->is_debug()) {
		$self->{log}->debug(q{view: $retval});
	}
  return $retval;
}


=head2 _get_create_association_sql

Create sql for given association.

=cut 

sub _get_create_association_sql {
  my ($self, $association) = @_;

	# Sanity checks on input
	if ( ref( $association ) ne 'ARRAY') {
    $self->{log}->error( q{Error in association input - cannot create association sql!} );
		return;
	}

	my (
			$table_name, $constraint_name, $key_column,
			$ref_table,  $ref_column,      $constraint_action
		 ) = @{$association};

	return
			qq{alter table $table_name add constraint $constraint_name }
      . $self->{newline}
      . $self->{indent}
      . qq{ foreign key ($key_column)}
      . $self->{newline}
      . $self->{indent}
      . qq{ references $ref_table ($ref_column) $constraint_action}
      . $self->{end_of_statement}
      . $self->{newline};
}


=head2 _get_create_index_sql

Create sql for all indices for given table.

=cut 

sub _get_create_index_sql {
  my ($self, $table) = @_;
	my $sqlstr = q{};

	# Sanity checks on input
	if ( ref( $table ) ne 'HASH') {
    $self->{log}->error( q{Error in table input - cannot create index sql!} );
		return;
	}

 OPERATION:
	foreach my $operation ( @{ $table->{ops} }) {

		if (ref($operation) ne 'ARRAY') {
			$self->{log}->error( q{Error in ops input - expect an ARRAY ref, got } . ref($operation));
			next OPERATION;
		}
		my ($opname,$optype,$colref) = ($operation->[0],$operation->[1],$operation->[2]);

		# 2nd element can be index, unique index, grant, etc
		next if ($optype !~ qr/^(unique )?index$/i);  

		$sqlstr .= 
			qq{create $optype $opname on } . $table->{name} 
      . q{ (} . join(q{,},@{$colref}) . q{) }
      . join(q{,},@{$self->{index_options}})
      . $self->{end_of_statement}
      . $self->{newline};
	}
	return $sqlstr;
}


# sub get_special_post  {}
# sub get_insert {}
# sub get_constraint_add {}


1;

__END__

=pod

Super class for outputting SQL

=cut
