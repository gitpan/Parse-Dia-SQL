package Parse::Dia::SQL;

# $Id: SQL.pm,v 1.13 2009/03/13 16:06:44 aff Exp $

=pod

=head1 NAME

Parse::Dia::SQL - Convert Dia class diagrams into SQL.

=head1 SYNOPSIS

    use Parse::Dia::SQL;
    my $dia = Parse::Dia::SQL->new(
      file => 't/data/TestERD.dia', 
      db   => 'db2' 
    );
    print $dia->get_sql();

    # or command-line version
    perl parsediasql --file t/data/TestERD.dia --db db2

=head1 DESCRIPTION

Dia is a diagram creation program for Linux, Unix and Windows released
under the GPL license.

Parse::Dia::SQL converts Dia class diagrams into SQL. 

Parse::Dia::SQL is the parser that interprets the .dia file(s) into an
internal datastructure.

Parse::Dia::SQL::Output (or one of its sub classes) can take the
datastructure and generate SQL statements it represents.

=head1 MODELLING HOWTO

See L<http://tedia2sql.tigris.org/usingtedia2sql.html>

=head1 DATABASE SUPPORT NOTE

The aim is to suppport the same set of databases as I<tedia2sql>.

=head2 Adding support for additional databases

Adding support for additional databases means to create a subclass of
Parse::Dia::SQL::Output.

Patches are welcome. 

=head1 AUTHOR

Parse::Dia::SQL is based on I<tedia2sql> by Tim Ellis and others.  See the
I<AUTHORS> file for details.

Modified by Andreas Faafeng, C<< <aff at cpan.org> >> for release on
CPAN.

=head1 BUGS

Please report any bugs or feature requests to C<bug-dia-sql at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dia-SQL>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Parse::Dia::SQL

You can also look for information at:

=over 4

=item * Project home

Documentation and public source code repository:

L<http://tedia2sql.tigris.org/>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dia-SQL>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dia-SQL>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dia-SQL>

=item * Search CPAN

L<http://search.cpan.org/dist/Dia-SQL>

=back

=head1 SEE ALSO

  Parse::Dia::SQL::Output

  http://tedia2sql.tigris.org/
  http://live.gnome.org/Dia

=head1 ACKNOWLEDGEMENTS

See the AUTHORS file.

=head1 LICENSE

This program is released under the GNU General Public License.

=head1 TERMINOLOGY

By I<database> we mean relational database managment system (RDBMS).

=cut

use warnings;
use strict;

use Data::Dumper;
use IO::Uncompress::Gunzip qw(:all);
use XML::DOM;
use Data::Dumper;
use File::Spec::Functions qw(catfile catdir);

use lib q{lib};
use Parse::Dia::SQL::Utils;
use Parse::Dia::SQL::Logger;
use Parse::Dia::SQL::Const;
use Parse::Dia::SQL::Output;

use Parse::Dia::SQL::Output::DB2;
use Parse::Dia::SQL::Output::Ingres;	 
use Parse::Dia::SQL::Output::Informix;	 
use Parse::Dia::SQL::Output::MySQL::InnoDB;
use Parse::Dia::SQL::Output::MySQL::MyISAM;
use Parse::Dia::SQL::Output::MySQL;
use Parse::Dia::SQL::Output::Oracle;	 
use Parse::Dia::SQL::Output::Postgres; 
use Parse::Dia::SQL::Output::Sas;			 
use Parse::Dia::SQL::Output::Sybase;

our $VERSION = '0.04'; 

=head1 METHODS

=over

=item new()

The constructor.  Mandatory arguments:

  file  - The .dia file to parse
  db    - The target database type

Dies if target database is unknown or unsupported.

=cut

sub new {
  my ($class, %param) = @_;

  # Argument 'file' overrides argument 'files'
  $param{files} = [ $param{file} ] if defined($param{file});

  my $self = {
    files       => $param{files}       || undef,
    db          => $param{db}          || undef,
    uml         => $param{uml}         || undef,
    fk_auto_gen => $param{fk_auto_gen} || undef,
    pk_auto_gen => $param{pk_auto_gen} || undef,
    default_pk  => $param{default_pk}  || undef,    # opt_p
    doc         => undef,
    nodelist    => undef,
    log         => undef,
    utils       => undef,
    const       => undef,
    fk_defs     => [],
    classes     => [],
    components     => [],                           # insert statements
    small_packages => [],
    output         => undef,
	index_options  => $param{index_options} || [],
	diaversion  => $param{diaversion} || undef,
    converted   => 0,  
  };

  bless($self, $class);

  $self->_init_log();
  $self->_init_utils();
  $self->_init_const();

  # Die unless database is supported
  if ( !grep( /^$self->{db}$/, $self->{const}->get_rdbms() ) ) {
    $self->{log}->logdie( qq{Unsupported database }
        . $self->{db}
        . q{. Valid options are }
        . join( q{, },  $self->{const}->get_rdbms() ) );
  }

  return $self;
}


# Initialize logger
sub _init_log {
  my $self = shift;
  my $logger = Parse::Dia::SQL::Logger::->new();
  $self->{log} = $logger->get_logger(__PACKAGE__);
  return 1;
}

# Initialize Constants component
sub _init_const {
  my $self = shift;
  $self->{const} = Parse::Dia::SQL::Const::->new();
  return 1;
}

# Initialize Parse::Dia::SQL::Utils class.
sub _init_utils {
  my $self = shift;
  $self->{utils} = Parse::Dia::SQL::Utils::->new(
    db         => $self->{db},
    default_pk => $self->{default_pk},
  );
  return 1;
}


# Return Output subclass for the database set in C<new()>.
# 
# Some params will be taken from this object unless explicitly set by caller:
# 
# 	classes 
# 	associations 
# 	small_packages
# 	components
# 	files
# 
# Returns undef if convert flag is false (to prevent output before
# conversion).
#
# Dies if db is unknown.
sub get_output_instance {
  my ($self, %param) = @_;

	# Make sure parsing is finished before we can output
  if (!$self->{converted}) {
		$self->{log}->error("Cannot output before convert!");
		return;
  }

  # Add some args to param unless they are set by caller 
  %param =
    map { $param{$_} = $self->{$_} unless exists($param{$_}); $_ => $param{$_} }
	  qw(classes associations small_packages components files index_options);

  if ($self->{db} eq q{db2}) {
		return Parse::Dia::SQL::Output::DB2->new(%param);
  } elsif ($self->{db} eq q{mysql-myisam}) {
    return Parse::Dia::SQL::Output::MySQL::MyISAM->new(%param);
  } elsif ($self->{db} eq q{mysql-innodb}) {
    return Parse::Dia::SQL::Output::MySQL::InnoDB->new(%param);
  } elsif ($self->{db} eq q{sybase}) {
    return Parse::Dia::SQL::Output::Sybase->new(%param);
  } elsif ($self->{db} eq q{ingres}) {
    return Parse::Dia::SQL::Output::Ingres->new(%param);
  } elsif ($self->{db} eq q{informix}) {
    return Parse::Dia::SQL::Output::Informix->new(%param);
  } elsif ($self->{db} eq q{oracle}) {
    return Parse::Dia::SQL::Output::Oracle->new(%param);
  } elsif ($self->{db} eq q{postgres}) {
    return Parse::Dia::SQL::Output::Postgres->new(%param);
  } elsif ($self->{db} eq q{sas}) {
    return Parse::Dia::SQL::Output::Sas->new(%param);
  }

  $self->{log}->logdie(qq{Failed to get instance for } . $self->{db});
}


# Parse the .dia file and create inner representation.
#
# Returns true on success.
#
# Returns undefined if called more than once on the same object.
sub convert {
  my $self = shift;

  if ($self->{converted}) {
		$self->{log}->info("Repeated conversion attempt discarded");
		return;
  }

  $self->_parse_doms();
  $self->_get_nodelists();
  $self->_parse_classes();          # parse
  $self->_parse_smallpackages();    # parse
  $self->_parse_associations();     # parse

  $self->{classes}        = $self->get_classes_ref();
  $self->{small_packages} = $self->get_smallpackages_ref();
  $self->{associations}   = $self->get_associations_ref();
  $self->{components}     = $self->get_components_ref();

  $self->{converted} = 1; # flag that we have parsed the file(s)
  return 1;
}

=item get_sql()

Return sql for given db.  Calls underlying methods that performs
parsing and sql generation.

=cut

sub get_sql {
  my $self   = shift;
  my $sqlstr = q{};
  $self->convert() or $self->{log}->logdie("failed to convert");
  my $output = $self->get_output_instance();
  return $output->get_sql();
}

# Uncompress the .dia file(s) and parse xml content. Push the parsed xml
# dom onto the docs list.
#
# Return the number of parsed files.
sub _parse_doms {
  my $self = shift;

  if (!$self->{files} || ref($self->{files}) ne q{ARRAY}){
      $self->{log}->logdie(q{Need at least one file!});
  }

  foreach my $file ( @{ $self->{files} } ) {

    if ( !-f $file || !-r $file ) {
      $self->{log}->logdie(qq{missing or unreadable file '$file'!});
    }

    # uncompress
    my $buffer = undef;
    gunzip $file => \$buffer
      or $self->{log}->logdie("gunzip failed: $GunzipError");

    # parse xml
    my $parser = new XML::DOM::Parser;
	eval {
	  push @{ $self->{docs} }, $parser->parse($buffer);
	};
	if ($@) {
	   $self->{log}->logdie(qq{parsing of file '$file' failed});
	}

  }
  return scalar( @{ $self->{docs} } );
}

# Returns the parsed xml dom documents (for testing only).
sub _get_docs {
  my $self = shift;
  return $self->{docs};
}

# Create nodelist from dom.  Return array of array XML::DOM::NodeList
# objects.
#
# Each inner array correspond to a separate input file.
sub _get_nodelists {
  my $self = shift;
  if ( !$self->{docs} ) {
    $self->{log}->error(q{missing docs list!});
    return;
  }

  foreach my $doc ( @{ $self->{docs} } ) {
    my $nodelist = $doc->getElementsByTagName('dia:object');
    push @{ $self->{nodelists} }, $nodelist;
  }

  return $self->{nodelists};
}

# Accessor
sub get_smallpackages_ref {
    my $self = shift;
    return $self->{small_packages};
}

# Go through nodelists and return number of 'SmallPackages' found
sub _parse_smallpackages {
  my $self   = shift;
  my @retarr = ();      # array of hashrefs to return

  $self->{log}->debug("_parse_smallpackages is called");

  if ( !$self->{nodelists} ) {
    $self->{log}->warn("nodelists are empty");
    return;
  }

  foreach my $nodelist ( @{ $self->{nodelists} } ) {

    $self->{log}->debug( "nodelist length" . $nodelist->getLength );

    for ( my $i = 0 ; $i < $nodelist->getLength ; $i++ ) {
      my $nodeType = $nodelist->item($i)->getNodeType;

      # sanity check -- a dia:object should be an element_node
      if ( $nodeType == ELEMENT_NODE ) {
        my $nodeAttrType = $nodelist->item($i)->getAttribute('type');
        my $nodeAttrId   = $nodelist->item($i)->getAttribute('id');
        $self->{log}
          ->debug("Node $i -- type=$nodeAttrType");

        if ( $nodeAttrType eq 'UML - SmallPackage' ) {

          # generic database statements
          $self->{log}->debug("call generateSmallPackageSQL");
          my $href =
            $self->_parse_smallpackage( $nodelist->item($i), $nodeAttrId );

          $self->{log}->debug( "_parse_smallpackage returned " . Dumper($href) );
          push @{$self->{small_packages}}, $href;
        }

      }
    }
  }
  # Return number of small_packages - undef if none
  if (defined($self->{small_packages})
    && ref($self->{small_packages}) eq 'ARRAY')
  {
    return scalar(@{ $self->{small_packages} });
  } else {
    return;
  }
}

# Returns hashref where key is name of SmallPackage and value is its
# content.
sub _parse_smallpackage {
  my $self             = shift;
  my $smallpackageNode = shift;

  my $nodelist = $smallpackageNode->getElementsByTagName('dia:attribute');
  $self->{log}->debug( "attributes: " . $nodelist->getLength );

  # parse out the 'stereotype' -- which in this case will be its name
  my $packName = undef;
  for ( my $i = 0 ; $i < $nodelist->getLength ; $i++ ) {
    my $currentNode  = $nodelist->item($i);
    my $nodeAttrName = $currentNode->getAttribute('name');
    $self->{log}->debug("nodeAttrName:$nodeAttrName");

    if ( $nodeAttrName eq 'stereotype' ) {
      $packName = $self->{utils}->get_string_from_node($currentNode);
      $self->{log}->debug("packName:$packName");
    }
    elsif ( $nodeAttrName eq 'text' ) {
      my $packText = $self->{utils}->get_string_from_node($currentNode);
      $self->{log}->debug("packText:$packText");

      # Create hashref and return it
      my $href = { $packName => $packText };
      return $href;
    }
  }
  return;    # Error: Did not find 'stereotype' element
}

# Return hashref with parsed classes.
sub get_classes_ref {
  my $self = shift;
  $self->{log}->warn(qq{The classes ref is undefined!}) if !$self->{classes};
  #$self->{log}->debug(q{classes:} . Dumper($self->{classes}));
  return $self->{classes};
}


# Returns hashref where key is name of class and value is its content.
sub _parse_classes {
  my $self    = shift;

  if ( !$self->{nodelists} ) {
    $self->{log}->warn("nodelists are empty");
    return;
  }
  my $fid = 0; # file sequence number

  foreach my $nodelist ( @{ $self->{nodelists} } ) {
    $fid++;
    $self->{log}
      ->debug("nodelist length " . $nodelist->getLength );

    for ( my $i = 0 ; $nodelist && $i < $nodelist->getLength ; $i++ ) {
      my $nodeType = $nodelist->item($i)->getNodeType;

      # sanity check -- a dia:object should be an element_node
      if ( $nodeType == ELEMENT_NODE ) {
        my $nodeAttrType = $nodelist->item($i)->getAttribute('type');
        my $nodeAttrId   = $nodelist->item($i)->getAttribute('id');

        $self->{log}->debug("Node $i -- type=$nodeAttrType");

        if ( $nodeAttrType eq 'UML - Class' ) {

          # table or view create
          $self->{log}->debug("$nodeAttrId");
          my $class = $self->_parse_class( $nodelist->item($i), [$fid, $nodeAttrId] );
          push @{$self->{classes}}, $class;

          #$self->{log}->debug("get_class:". Dumper($class));

        }
        elsif ( $nodeAttrType eq 'UML - Component' ) {
          #$self->{log}->debug("get_component");

          # insert statements - hash ref where table is key
          my $component = $self->_parse_component ($nodelist->item($i), [$i, $nodeAttrId]);
          push @{$self->{components}}, $component if defined($component);
        }
      }
    }
  }
  $self->{log}->debug("return");
  return $self->{classes};
}

# Accessor
sub get_components_ref {
    my $self = shift;
    return $self->{components};
}


# Parse a component and take our what is needed to create inserts.
#
# Returns a hash reference.
sub _parse_component {
  my $self      = shift;
  my $component = shift;
  my $id        = shift;    # it's a array ref..

  my ( $i, $currentNode, $comp_name, $comp_text, $nodeType, $nodeAttrName,
    $nodeAttrId, $nodeList );
	my @insertTexts;

	$nodeList = $component->getElementsByTagName ('dia:attribute');

	# parse out the 'stereotype' -- which in this case will
	# be its name
	undef ($comp_name);
	$i=0;

	# pass 1 to get $comp_name
	while ($i < $nodeList->getLength && (!$comp_name || !$comp_text)) {
		$currentNode = $nodeList->item($i);
		$nodeAttrName = $currentNode->getAttribute ('name');
	
		if ($nodeAttrName eq 'stereotype') {
			$comp_name = $self->{utils}->get_string_from_node ($currentNode);
			$self->{log}->debug(qq{comp_name=$comp_name});

			# Dia <0.9 puts strange characters before & after
			# the component stereotype
			if ($self->{diaversion} && $self->{diaversion} < 0.9) {
				$comp_name =~ s/^&#[0-9]+;//s;
				$comp_name =~ s/&#[0-9]+;$//s;
			}

		} elsif ($nodeAttrName eq 'text') {
			$comp_text = $self->{utils}->get_string_from_node ($currentNode);
			#if ($verbose) { print "Got text from node... (probably multiline)\n"; }

			# first, get rid of the # starting and ending the text
			$comp_text =~ s/^#//s;
			$comp_text =~ s/#$//s;
		}

		$i++;
	}

	# Fail unless both name and text are defined
	if (!$comp_name || !$comp_text) {
		$self->{log}->error(qq{Component does not have both name and text, not generating SQL});
		return;
	}

	# Return a hash ref that represents the component
	return {name => $comp_name, text => $comp_text}; 
}

# Parse a CLASS and salt away the information needed to generate its SQL
# DDL.  
#
# Returns a hash reference.
sub _parse_class {
  my $self  = shift;
  my $class = shift;
  my $id    = shift; # it's a array ref..

  my $warns = 0;

  # get the Class name
  my $className =
    $self->{utils}
    ->get_value_from_object( $class, "dia:attribute", "name", "name", "string",
    0 );

  # determine if this Class is a Table or View
  my $classAbstract =
    $self->{utils}
    ->get_value_from_object( $class, "dia:attribute", "name", "abstract",
    "boolean", 0 );
  my $classComment =
    $self->{utils}
    ->get_value_from_object( $class, "dia:attribute", "name", "comment", "string",
    1 );
  my $classStereotype =
    $self->{utils}
    ->get_value_from_object( $class, "dia:attribute", "name", "stereotype",
    "string", 0 );
  my $classType;
  if ( $classAbstract eq 'true' ) {
    $classType = 'view';
  }
  else {
    $classType = 'table';
  }

  if ( $self->{log}->is_debug() ) {
		## no critic (ProhibitNoWarnings)
    no warnings q{uninitialized};
    $self->{log}
      ->debug("Parsing UML Class name      : $className");
    $self->{log}
      ->debug("Parsing UML Class abstract  : $classAbstract");
    $self->{log}
      ->debug("Parsing UML Class comment   : $classComment");
    $self->{log}
      ->debug("Parsing UML Class stereotype: $classStereotype");
    $self->{log}
      ->debug("Parsing UML Class type      : $classType");
  }

  if ( $self->{utils}->name_case($classStereotype) eq
       $self->{utils}->name_case("placeholder") )
  {

    # it's merely a placeholder - it's not allowed attributes or operations
    my $attribNode =
      $self->{utils}
      ->get_node_from_object( $class, "dia:attribute", "name", "attributes", 0 );
    my $operNode =
      $self->{utils}
      ->get_node_from_object( $class, "dia:attribute", "name", "operations", 0 );
    $self->{log}
      ->logdie("Class $className has placeholder with attributes or operations")
      if ( $attribNode->getElementsByTagName("dia:composite")->getLength() > 0
      || $operNode->getElementsByTagName("dia:composite")->getLength() > 0 );

    # Record the placeholder's name against its ID; refers will be the
    # id of the class to actually use; to be filled in later
    $self->{umlClassPlaceholder}{ $id->[0] }{ $id->[1] } = {
      name   => $className,
      refers => -1
    };
    $self->{log}->logdie("TODO: placeholder");
    return $warns == 0;
  }

  # Associations will need this associative array to understand
  # what their endpoints are connected to and to find its
  # key(s)
  my $classLookup = {
    #    class   => $class,        # reference to class DOM
    name    => $className,    # Class name
    type    => $classType,    # Class type table/view
    attList => [],            # list of attributes
    atts    => {},            # lookup table of attributes
    pk      => [],            # list of primary key attributes
    uindxc  => {},            # lookup of unique index column names
    uindxn  => {},            # lookup of unique index names
    ops     => [],            # list of operations
  };

  $self->{umlClassLookup}->{$id->[0]}{$id->[1]} = $classLookup;

  # get the Class attributes
  my $attribNode =
    $self->{utils}
    ->get_node_from_object( $class, "dia:attribute", "name", "attributes", 0 );

  # need name, type, value, and visibility for each
  foreach
    my $singleAttrib ( $attribNode->getElementsByTagName("dia:composite") )
  {
    my $attribName =
      $self->{utils}
      ->get_value_from_object( $singleAttrib, "dia:attribute", "name", "name",
      "string", 0 );
    my $attribType =
      $self->{utils}
      ->get_value_from_object( $singleAttrib, "dia:attribute", "name", "type",
      "string", 0 );
    my $attribVal =
      $self->{utils}
      ->get_value_from_object( $singleAttrib, "dia:attribute", "name", "value",
      "string", 0 );
    my $attribVisibility =
      $self->{utils}
      ->get_value_from_object( $singleAttrib, "dia:attribute", "name",
      "visibility", "number", 0 );
    my $attribComment =
      $self->{utils}
      ->get_value_from_object( $singleAttrib, "dia:attribute", "name", "comment",
      "string", 1 );

    $self->{log}->debug(
	"attribute: $attribName - $attribType - $attribVal - $attribVisibility"
    );
    my $att = [
      $attribName,       $attribType, $attribVal,
      $attribVisibility, $attribComment
    ];
    push @{ $classLookup->{attList} }, $att;

    # Set up symbol table info in the class lookup
    $classLookup->{atts}{ $self->{utils}->name_case($attribName) } = $att;
    push @{ $classLookup->{pk} }, $att
      if ( $attribVisibility && $attribVisibility eq 2 );
  }

  # get the Class operations
  my $operationDescs = [];
  my $operNode =
    $self->{utils}
    ->get_node_from_object( $class, "dia:attribute", "name", "operations", 0 );

  # need name, type, (parameters...)
  foreach
    my $singleOperation ( $operNode->getElementsByTagName("dia:composite") )
  {
    my $paramString = "";

    # only parse umloperation dia:composites
    if ( $singleOperation->getAttributes->item(0)->toString eq
      'type="umloperation"' )
    {
      my $operName =
        $self->{utils}
        ->get_value_from_object( $singleOperation, "dia:attribute", "name", "name",
        "string", 0 );
      my $operType =
        $self->{utils}
        ->get_value_from_object( $singleOperation, "dia:attribute", "name", "type",
        "string", 0 );
      my $operTemplate =
        $self->{utils}
        ->get_value_from_object( $singleOperation, "dia:attribute", "name",
        "stereotype", "string", 0 )
        || '';
      my $operComment =
        $self->{utils}
        ->get_value_from_object( $singleOperation, "dia:attribute", "name",
        "comment", "string", 1 );
      my $operParams =
        $self->{utils}
        ->get_node_from_object( $singleOperation, "dia:attribute", "name",
        "parameters", 0 );
      my @paramList  = $singleOperation->getElementsByTagName("dia:composite");
      my $paramCols  = [];
      my $paramDescs = [];

      foreach my $singleParam (@paramList) {
        my $paramName =
          $self->{utils}
          ->get_value_from_object( $singleParam, "dia:attribute", "name", "name",
          "string", 0 );
        if ( $operType =~ /index/
          && !$classLookup->{atts}{ $self->{utils}->name_case($paramName) } )
        {
          $self->{log}
            ->warn("Index $operName references undefined attribute $paramName");

          #$warns++; $errors++;
          next;
        }
        push @$paramDescs, $paramName;
        push @$paramCols,
          [
          $paramName,
          $classLookup->{atts}{ $self->{utils}->name_case($paramName) }[1]
          ];
      }

      $self->{log}->debug(
"Got operation: $operName / $operType / ($paramString) / ($operTemplate)"
      );
      push @$operationDescs,
        [ $operName, $operType, $paramDescs, $operTemplate, $operComment ];

      # Set up the index symbol table info in the class lookup
      $operType =~ s/\s//g;    # clean up any spaces in the type
      if ( $self->{utils}->name_case($operType) eq
        $self->{utils}->name_case('uniqueindex') )
      {
        $classLookup->{uindxn}{ $self->{utils}->name_case($operName) } =
          $paramCols;
        $classLookup->{uindxc}{ $self->{utils}->name_case($paramString) } =
          $paramCols;
      }
    }
    $classLookup->{ops} = $operationDescs;
  }

  $self->{log}->debug( "returning " . Dumper($classLookup) );
  return $classLookup;
}

# Return hashref with parsed associations.
sub get_associations_ref {
  my $self = shift;
  return $self->{fk_defs};
}


#  Scan the nodeList for UML Associations and return them.
sub _parse_associations {
  my $self = shift;
  my $fid = 0; # file sequence number

  my $assocErrs = 0;
  foreach my $nodelist ( @{ $self->{nodelists} } ) {
    $fid++; 

    for ( my $i = 0 ; $i < $nodelist->getLength ; $i++ ) {
      my $nodeType = $nodelist->item($i)->getNodeType;

      # sanity check -- a dia:object should be an element_node
      if ( $nodeType == ELEMENT_NODE ) {
        my $nodeAttrType = $nodelist->item($i)->getAttribute('type');
        my $nodeAttrId   = $nodelist->item($i)->getAttribute('id');


        if ( $nodeAttrType eq 'UML - Association' ) {
	    $self->{log}->debug("Association Node $i -- type=$nodeAttrType id=$nodeAttrId");
		# TODO: Check return value:
	    $self->_parse_association( $nodelist->item($i), [ $fid, $nodeAttrId ] )
        }
      }

    }
  }

  return $self->{fk_defs};
}

# Generate the foreign key relationship between two tables: classify
# the relationship, and generate the necessary constraints and centre
# (join) tables.
sub _parse_association {
  my $self        = shift;
  my $association = shift;
  my $id          = shift; # it's an array ref..

  my ( $i, $currentNode, $assocName, $assocDirection, $nodeType, $nodeAttrName,
    $nodeAttrId, $nodeList );
  my ( %leftEnd, %rightEnd, $connectionNode, $leftConnectionHandle,
    $rightConnectionHandle );

  $self->{log}->debug("Parsing UML Association file=[$id->[0]] id=$id->[1]");

  $nodeList = $association->getElementsByTagName('dia:attribute');

  # parse out the name, direction, and ends
  undef($assocName);
  $i = 0;
  while ( $i < $nodeList->getLength ) {
    $currentNode  = $nodeList->item($i);
    $nodeAttrName = $currentNode->getAttribute('name');

    if ( $nodeAttrName eq 'name' ) {
      $assocName = $self->{utils}->get_string_from_node($currentNode);
      $self->{log}->debug("Got association name=$assocName"); 
    }
    elsif ( $nodeAttrName eq 'direction' ) {
      $assocDirection = $self->{utils}->get_num_from_node($currentNode);
    }
    elsif ( $nodeAttrName eq 'ends' ) {

      # cycle through dia:composite entries looking for string role &
      # numeric aggregate values get the attributes for this
      # association -- each is a dia:composite
      #
      # there should only be one dia:composite within the association

      my @tags = ( 'arole', '9aggregate', 'bclass_scope', 'amultiplicity' );
      %leftEnd = $self->{utils}->get_node_attribute_values(
        $association->getElementsByTagName('dia:composite')->item(0), @tags );
      %rightEnd = $self->{utils}->get_node_attribute_values(
        $association->getElementsByTagName('dia:composite')->item(1), @tags );
    }

    $i++;
  }

  # parse out the 'connections', that is, the classes on either end
  $connectionNode =
    $association->getElementsByTagName('dia:connections')->item(0);

  $leftConnectionHandle =
    $connectionNode->getElementsByTagName('dia:connection')->item(0);
  $rightConnectionHandle =
    $connectionNode->getElementsByTagName('dia:connection')->item(1);

  # Get the classes' object IDs

  $leftConnectionHandle = $leftConnectionHandle->getAttribute('to')
    if ($leftConnectionHandle);
  $rightConnectionHandle = $rightConnectionHandle->getAttribute('to')
    if ($rightConnectionHandle);

  # Check that the association is connected at both ends
  if ( !( $leftConnectionHandle && $rightConnectionHandle ) ) {
    my $goodEnd;
    $goodEnd = $leftConnectionHandle  if ($leftConnectionHandle);
    $goodEnd = $rightConnectionHandle if ($rightConnectionHandle);
    $goodEnd = $self->uml_class_lookup( [ $id->[0], $goodEnd ] )->{name}
      if ($goodEnd);
    $self->{log}->warn("Association " 
      . ( $assocName ? $assocName : "<UNNAMED>" )
      . (
      $goodEnd
      ? " only connected at one end - " . $goodEnd
      : " not connected at either end"
      ));
    $self->{log}->warn("foreign key constraint not created");
    return;
  }

  $self->{log}->debug(
    "  * (UNUSED) direction=$assocDirection (aggregate determines many end)");
  $self->{log}->debug( "  * leftEnd="
      . $leftEnd{'role'} . " agg="
      . $leftEnd{'aggregate'}
      . " classId="
      . $leftConnectionHandle );
  $self->{log}->debug( "  * rightEnd="
      . $rightEnd{'role'} . " agg="
      . $rightEnd{'aggregate'}
      . " classId="
      . $rightConnectionHandle );

  my $leftMult  = $self->{utils}->classify_multiplicity( $leftEnd{'multiplicity'} );
  my $rightMult = $self->{utils}->classify_multiplicity( $rightEnd{'multiplicity'} );

  # Get primary key end in one-to-n (incl 1-to-1) associations
  # The encoding for this is different between default ERD mode and UML mode
  my $pkSide = 'none';
  my $arity;
  if ( ( $self->{uml} ? $rightEnd{'aggregate'} : $leftEnd{'aggregate'} )
    || $self->{uml} && $rightMult =~ '^z?one$' && $leftMult =~ /^z?many$/ )
  {

    # Right side is 'one' end; one-to-many
    $pkSide = 'right';
    $arity  = 'zmany';
  }
  elsif ( ( $self->{uml} ? $leftEnd{'aggregate'} : $rightEnd{'aggregate'} )
    || $self->{uml} && $leftMult =~ '^z?one$' && $rightMult =~ /^z?many$/ )
  {

    # Left side is 'one' end; one-to-many
    $pkSide = 'left';
    $arity  = 'zmany';
  }
  elsif ( $assocDirection eq 1
    && ( !$self->{uml} || ( $rightMult eq 'one' && $leftMult =~ /^z?one$/ ) ) )
  {

    # Right side is 'one' end; one-to-zero-or-one
    $pkSide = 'right';
    $arity  = 'zone';
  }
  elsif ( $assocDirection eq 2
    && ( !$self->{uml} || ( $leftMult eq 'one' && $rightMult =~ /^z?one$/ ) ) )
  {

    # Left side is 'one' end; one-to-zero-or-one
    $pkSide = 'left';
    $arity  = 'zone';
  }

  my $leftClass  = $self->uml_class_lookup( [ $id->[0], $leftConnectionHandle ] );
  my $rightClass = $self->uml_class_lookup( [ $id->[0], $rightConnectionHandle ] );

  my $ok = 0;

  if ( $pkSide ne 'none' ) {

    # If the classification above succeeded, generate the
    # keys (if needed) and the FK constraints for a one-to-
    # association
    $ok = $self->generate_one_to_any_association(
      $assocName, $pkSide,     $arity, $leftClass,
      \%leftEnd,  $rightClass, \%rightEnd
    );
  }
  elsif ( ( $self->{uml} || $assocDirection eq 0 )
    && $leftMult  =~ /^z?many$/
    && $rightMult =~ /^z?many$/ )
  {

    # If the classification above failed, and the association is
    # many-to-many; generate the centre (join) table, its constraints
    # and the classes' primary keys (if needed)
    $ok = $self->generate_many_to_many_association(
      $assocName,  $leftClass, $leftEnd{'role'},
      $rightClass, $rightEnd{'role'}
    );
  }
  else {
    $self->{log}->warn(
	"Couldn't classify $leftClass->{name}:$rightClass->{name} to generate SQL: $leftMult:$rightMult");
    $ok = 0;
  }

#  $errors++ if ( !$ok );

  return $ok;
}

# Look up a class given the XML id of the class, taking into account
# placeholder classes.
sub uml_class_lookup {
  my $self = shift;
  my $id   = shift;

  if ( my $placeHolder = $self->{umlClassPlaceholder}{ $id->[0] }{ $id->[1] } )
  {
    $self->{log}->debug(
      "Map reference to {$id->[0]}{$id->[1]} to ",
      $placeHolder->{refers},
      " (", $placeHolder->{name}, ")"
    );
    $id = $placeHolder->{refers};
  }
  return $self->{umlClassLookup}{ $id->[0] }{ $id->[1] };
}


# Generate SQL for a many to many association including generating the
# centre (join) table.
sub generate_many_to_many_association {
  my $self             = shift;
  my $assocName        = shift;
  my $leftClassLookup  = shift;
  my $leftRole         = shift;
  my $rightClassLookup = shift;
  my $rightRole        = shift;

  $self->{log}->debug("generate_many_to_many_association: assocName: $assocName");
  $self->{log}->debug("generate_many_to_many_association: leftClassLookup->{name}: ".$leftClassLookup->{name} );
  $self->{log}->debug("generate_many_to_many_association: leftRole:  $leftRole");
  $self->{log}->debug("generate_many_to_many_association: rightClassLookup->{name}: ".$rightClassLookup->{name} );
  $self->{log}->debug("generate_many_to_many_association: rightRole: $rightRole");

  my @centreCols;
  my ( $leftFKName,  $rightFKName );
  my ( $leftEndCols, $rightEndCols );
  my ( $leftFKCols,  $rightFKCols );

  if ( $leftClassLookup->{type} ne 'table'
    || $rightClassLookup->{type} ne 'table' )
  {
    $self->{log}->warn( "View in $assocName"
      . " ($leftClassLookup->{name},$rightClassLookup->{name} ne 'table')"
      . ": Many-to-many associations are only supported between tables");
#    $errors++;
    return;
  }

  # Generate the centre (join) table name if the user hasn't specified one

  $assocName =
    $self->{utils}->make_name( 0, $leftClassLookup->{name}, $rightClassLookup->{name}, $self->{db} )
    if ( !$assocName );

  # Build the centre table for the left (A) end of the association

  if (
    !$self->add_centre_cols(
      $assocName,   \@centreCols, $leftRole,     $rightRole,
      \$leftFKName, \$leftFKCols, \$leftEndCols, $leftClassLookup
    )
    )
  {
	$self->{log}->debug("add_centre_cols return false - returning");
    return;
  }

  # Build the centre table for the right (B) end of the association

  if (
    !$self->add_centre_cols(
      $assocName,    \@centreCols,  $rightRole,     $leftRole,
      \$rightFKName, \$rightFKCols, \$rightEndCols, $rightClassLookup
    )
    )
  {
	$self->{log}->debug("add_centre_cols return false - returning");
    return;
  }

  # Make the association table
  $self->{log}->debug("Call gen_table_view_sql assocName=$assocName");

  $self->gen_table_view_sql(
    $assocName,
    "table",
    "Association between $leftClassLookup->{name}"
      . " and $rightClassLookup->{name}",
    [@centreCols],
    []
  );

  # generate the constraint code:
  #	foreign key -> referenced attribute
  $self->{log}->debug("Call save_foreign_key (left to right)");

  $self->save_foreign_key(
    $assocName,                  ## From table
    $leftFKName,                 ## name of foreign key constraint
    $leftFKCols,                 ## foreign key column in assoc tbl
    $leftClassLookup->{name},    ## Table referenced
    $leftEndCols,                ## Column in table referenced
    'on delete cascade'          ## Trash when no longer referenced
  );

  # generate the constraint code:
  #	referenced attribute <- foreign key
  $self->{log}->debug("Call save_foreign_key (right to left)");

  $self->save_foreign_key($assocName, $rightFKName, $rightFKCols,
    $rightClassLookup->{name},
    $rightEndCols, 'on delete cascade');

  return 1;
}

# Create datastructure that represents given Table or View SQL and
# store in classes reference.
sub gen_table_view_sql {
  my $self             = shift;
  my $objectName       = shift;
  my $objectType       = shift;
  my $objectComment    = shift;
  my $objectAttributes = shift;
  my $objectOperations = shift;

  my $classLookup = {
    name    => $objectName,    # Object name
    type    => $objectType,    # Object type table/view
    attList => $objectAttributes,            # list of attributes
    atts    => $objectAttributes,            # lookup table of attributes
    pk      => [],            # list of primary key attributes
    uindxc  => {},            # lookup of unique index column names
    uindxn  => {},            # lookup of unique index names
    ops     => $objectOperations,            # list of operations
  };

  # Push this generated table to classes array
  push @{ $self->{classes} }, $classLookup;

  $self->{log}->debug("classes: ".Dumper($self->{classes}));

  return 1;
}

# Add column descriptors for a centre (join) table to an array of
# descriptors passed.
sub add_centre_cols {
  my $self       = shift;
  my $assocName  = shift;  # For warning messages & constructing constraint name
  my $cols       = shift;  # Where to add column descriptors
  my $pkRole     = shift;  # Names for the PK end
  my $fkRole     = shift;  # Names for the FK end
  my $fkCName    = shift;  # Assemble FK constraint name here
  my $fkColNames = shift;  # Assemble FK column names here
  my $pkColNames = shift;  # Assemble PK column names here
  my $classDesc  = shift;  # Class lookup descriptor

  my $className = $classDesc->{name};     # Name of target class
  my $pk        = $classDesc->{pk};       # List of primary key attributes
  my $uin       = $classDesc->{uindxn};   # List of unique index by name
  my $uic       = $classDesc->{uindxc};   # List of unique index by column names

  my ( undef, $pkRoleNames ) = split( /\s*:\s*/, $pkRole );
  my ( $fkRoleNames, undef ) = split( /\s*:\s*/, $fkRole );

  my $pkAtts = $pk;

  # Use user-supplied names for the primary key if given

  if ($pkRoleNames) {
    $pkRoleNames =~ s/\s//g;
    my $pkNames = $self->{utils}->names_from_attlist($pk);
    if ( $self->{utils}->name_case($pkNames) eq
      $self->{utils}->name_case($pkRoleNames) )
    {

      # It's an explicit reference to the primary key
      $pkAtts = $pk;
    }
    else {

      # Try a unique index
      if ( !( $pkAtts = $uin->{$pkRoleNames} )
        && !( $pkAtts = $uic->{$pkRoleNames} ) )
      {
        $self->{log}->warn(
"In association $assocName $pkRoleNames doesn't refer to a primary key or unique index");
        return 0;
      }
    }
  }

  # If there was no user-supplied PK name, but PK generation is allowed, do it

  if ( $self->{default_pk} && !@$pkAtts && $classDesc->{type} eq 'table' ) {
    $self->{utils}->add_default_pk( $classDesc, '' );
    $pkAtts = $classDesc->{pk};
  }

  # No primary key (or unique index) suitable
  if ( @$pkAtts == 0 ) {
    $self->{log}->warn(
"Association $assocName referenced class $classDesc->{name} must have a primary key");
    return 0;
  }

  my @pkCols;
  my @fkCols;
  my $pk0;
  my @fkCNames;

  # If the user supplied foreign key names, use them
  if ($fkRoleNames) {
    @fkCNames = split /\s*,\s*/, $fkRoleNames;
    if ( @fkCNames != @$pkAtts ) {
      $self->{log}->warn(
"Association $assocName $fkRoleNames has the wrong number of attributes");
      return 0;
    }
  }

  # Generate the columns in the centre (join) table

  foreach my $i ( 0 .. $#{$pkAtts} ) {
    my $pkFld = $pkAtts->[$i];
    $pk0 = $pkFld->[0] if ( !$pk0 );
    my $colName =
        $fkRoleNames
      ? $fkCNames[$i]
      : $self->{utils}->make_name( 1, $className, $pkFld->[0] );
    push @fkCols, $colName;

    # The generated columns in the centre (join) table take the
    # type of the corresponding PK, and are part of centre table's
    # primary key (2==protected for the visibility).
    push @$cols, [ $colName, $pkFld->[1], '', 2, '' ];

    # Build the list of PK names
    push @pkCols, $pkFld->[0];
  }
  $$pkColNames = join ',', @pkCols if ( !$$pkColNames );
  $$fkColNames = join ',', @fkCols;
  $$fkCName =
    $self->{utils}->make_name( 1, $assocName, '_fk_', $className, $pk0 );
  return 1;
}


# Generate data for SQL generation for an association where one side has
# multiplicity one; no additional table is necessary.
sub generate_one_to_any_association {
  my $self          = shift;
  my $userAssocName = shift;
  my $pkSide        = shift;
  my $arity         = shift;
  my $pkClassLookup = shift;
  my $pkEnd         = shift;
  my $fkClassLookup = shift;
  my $fkEnd         = shift;

  # The caller used 'left' and 'right'; change this to
  # primary key/foreign key side of the association

  if ( $pkSide eq 'right' ) {
    my $tClassLookup = $pkClassLookup;
    my $tEnd         = $pkEnd;
    $pkClassLookup = $fkClassLookup;
    $pkEnd         = $fkEnd;
    $fkClassLookup = $tClassLookup;
    $fkEnd         = $tEnd;
  }

  # MAke the association name if necessary

  my $assocName = $userAssocName;
  if ( !$assocName ) {
    $assocName = $self->{utils}->make_name( 0, $pkClassLookup->{name}, $fkClassLookup->{name} );
  }

  # Classify the multiplicity (if given) of the ends of the association

  my $pkMult =
    $self->{utils}->classify_multiplicity( $pkEnd->{'multiplicity'} );
  my $fkMult =
    $self->{utils}->classify_multiplicity( $fkEnd->{'multiplicity'} );

  # By default, foreign keys are constrained to be 'not null'
  my $defFKnull = 'not null';

  # Work out the constraint action for the foreign key
  my $constraintAction = '';
  if ( $self->{uml} ) {

    # UML interpretation

    # Only one of the left and right end aggregation can be
    # non-zero; 1 = aggregation, 2 = composition.
    my $aggregation = $pkEnd->{'aggregate'} + $fkEnd->{'aggregate'};
    if ( $aggregation == 0 ) {    # No semantics specified
      $constraintAction = '';
    }
    elsif ( $aggregation == 1 ) {    # Aggregation
      $constraintAction = 'on delete set NULL';
      $defFKnull        = 'null';
    }
    elsif ( $aggregation == 2 ) {    # Composition
      $constraintAction = 'on delete cascade';
    }
  }
  else {

    # ERD interpretation

    # If Utils::classify_multiplicity didn't understand the multiplicity
    # field, then assume it's a constraint action, and set the
    # multiplicity classification to 'none'

    if ( $fkMult eq 'undef' ) {
      $constraintAction = $fkEnd->{'multiplicity'};
      $fkMult           = 'none';
    }

    # If the constraint action is 'on delete set null', then
    # allow the FK to have null value

    if ( $constraintAction =~ /on\s+delete\s+set\s+null/i ) {
      $defFKnull = 'null';
    }

    # tedia2sql v1.2.9b usage of 'on delete clause'
    # The 'on cascade delete' clauses were on opposite ends of
    # the association for one-to-many and one-to-one for ERD mode!
    #		if ($arity eq 'zmany' && $fkMult eq 'undef') {
    #			$constraintAction = $fkEnd->{'multiplicity'};
    #			$fkMult = 'none';
    #		} elsif ($arity eq 'zone' && $pkMult eq 'undef') {
    #			$constraintAction = $pkEnd->{'multiplicity'};
    #			$pkMult = 'none';
    #		}
  }

  # If the arity implied by the association is one-to-many, set the
  # arity classifications appropriately if they weren't given

  if ( $arity eq 'zmany' ) {
    $pkMult = 'one'   if ( $pkMult eq 'none' );
    $fkMult = 'zmany' if ( $fkMult eq 'none' );
    if (
         $pkMult ne 'one'
      || $self->{uml}
      ? $fkMult !~ /^z?(many|one)$/
      : $fkMult !~ /^z?many$/
      )
    {
      $self->{log}->warn( "Inappropriate multiplicity ($pkMult->$fkMult)"
        . " specified in $assocName");
      return 0;
    }
  }
  elsif ( $arity eq 'zone' ) {
    $pkMult = 'one'  if ( $pkMult eq 'none' );
    $fkMult = 'zone' if ( $fkMult eq 'none' );
    if ( $pkMult ne 'one'
      || $fkMult !~ /^z?one$/ )
    {
      $self->{log}->warn( "Inappropriate multiplicity ($pkMult->$fkMult)"
        . " specified in $assocName");
      return 0;
    }
  }

  $defFKnull = 'null' if ( $pkMult =~ /^z(many|one)$/ );

  # Generate names if they haven't been specified
  my $pkEndKey = $pkEnd->{'role'};
  my $fkEndKey = $fkEnd->{'role'};
  my $pkPK     = $pkClassLookup->{pk};        # List of primary key attributes
  my $pkUIn    = $pkClassLookup->{uindxn};    # List of unique index descriptors
  my $pkUIc    = $pkClassLookup->{uindxc};    # List of unique index descriptors
  my $pkAtts   = undef;
  my $fkAtts   = undef;

  if ($pkEndKey) {

    # Use user-supplied names for the primary key if given

    if ( $pkClassLookup->{type} eq 'table' ) {
      $pkEndKey =~ s/\s//g;
      my $pkNames = $self->{utils}->names_from_attlist($pkPK);
      if ( $self->{utils}->name_case($pkNames) eq
        $self->{utils}->name_case($pkEndKey) )
      {

        # It's an explicit reference to the primary key
        $pkAtts = $pkPK;
      }
      else {

        # Try a unique index
        if ( !( $pkAtts = $pkUIn->{ $self->{utils}->name_case($pkEndKey) } )
          && !( $pkAtts = $pkUIc->{ $self->{utils}->name_case($pkEndKey) } ) )
        {
          $self->{log}->warn( "In association $assocName"
            . " $pkEndKey doesn't refer to a"
            . " primary key or unique index");
          return 0;
        }
        $self->{log}->info("null PK - unique index in $pkClassLookup->{name}")
          if ( !$pkAtts );
      }
    }
    else {
      $pkAtts = $self->{utils}->attlist_from_names( $pkClassLookup, $pkEndKey );
    }
  }
  else {

    # Otherwise just use the marked primary key...

    $pkAtts   = $pkPK;
    $pkEndKey = namesFromAttList($pkAtts);
  }

  # If there was no user-supplied PK name, but PK generation is allowed, do it

  if ( $self->{fk_auto_gen} && !@$pkAtts ) {
    $self->{utils}->add_default_pk( $pkClassLookup, $pkEndKey );
    $pkAtts   = $pkClassLookup->{pk};
    $pkEndKey = $self->{utils}->names_from_att_list($pkAtts);
  }

  # Use user-supplied foreign key names if given
  if ($fkEndKey) {
    $fkEndKey =~ s/\s//g;
  }
  else {
    $fkEndKey = fkNamesFromAttList( $pkClassLookup->{name}, $pkAtts );
  }
  $fkAtts = $self->{utils}->attlist_from_names( $fkClassLookup, $fkEndKey );
	#$self->{log}->warn(q{fkAtts: }. Dumper($fkAtts));

 # If we're not auto-generating foreign keys, the number of PK and FK attributes
 # must be equal
  if ( ( !$self->{pk_auto_gen} || $fkClassLookup->{type} ne 'table' )
    && @$pkAtts != @$fkAtts )
  {
    $self->{log}->warn( "In association $assocName $fkEndKey"
      . " has attributes not declared in $fkClassLookup->{name}");
    return;
  }

  # Add default FK attributes if required...
  $fkAtts =
    $self->{utils}->add_default_fk( $fkClassLookup, $fkEndKey, $fkAtts, $pkAtts, $defFKnull )
    if ( $self->{pk_auto_gen}
    && $fkClassLookup->{type} eq 'table'
    && @$pkAtts != @$fkAtts );

  # Number and types of PK and FK attributes must match...
  if ( @$pkAtts != @$fkAtts ) {
    $self->{log}->warn(
      "Number of PK and FK attributes don't match " . " in $assocName" );
    return;
  }

  # TODO: Add support for opt_M (ignore type mismatch)
  if (
    !$self->{utils}->check_att_list_types(
      $assocName, $pkClassLookup, $fkClassLookup,
      $pkAtts,    $fkAtts,        $self->{db}
    )
    )
  {
    my $pkNames = $self->{utils}->names_from_attlist($pkAtts);
    my $fkNames = $self->{utils}->names_from_attlist($fkAtts);
    $self->{log}
      ->warn( "Types of ($pkNames) don't match ($fkNames)" . " in $assocName");
    return;
  }

  # Use the user-supplied FK constraint name; otherwise generate one
  my $fkName =
      $userAssocName && !$self->{uml}
    ? $userAssocName
    : $self->{utils}->make_name( 1, $fkClassLookup->{name}, '_fk_', $fkAtts->[0][0] );

  # Save the data needed to build the constraint
  $self->save_foreign_key(
    $fkClassLookup->{name},
    $fkName, $fkEndKey, $pkClassLookup->{name},
    $pkEndKey, $constraintAction
  );
  return 1;
}


# Save the details of foreign keys for output later (i.e. push onto
# fk_defs array ref).
sub save_foreign_key {
  my $self = shift;
  my $sourceTable = shift;
  my $assocName        = shift;
  my $leftEnd          = shift;
  my $targetTable      = shift;
  my $rightEnd         = shift;
  my $constraintAction = shift;

  push @{ $self->{fk_defs} },
    [
    $sourceTable, $assocName, $leftEnd,
    $targetTable, $rightEnd,  $constraintAction
    ];

  $self->{log}->debug("save_foreign_key: fk_defs is now: " . Dumper($self->{fk_defs}));

  return 1;
}

1;

__END__


# End of Parse::Dia::SQL

=back

