
# $Id: 904-kwalitee.t,v 1.1 2009/02/23 07:36:17 aff Exp $

use strict;
use warnings;

use Test::More;

BEGIN {
  eval { require Test::Kwalitee;  };
  plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;

  plan( skip_all => 'AUTHOR_TEST must be set for kwalitee test; skipping' )
    if ( !$ENV { 'AUTHOR_TEST' } );
}

Test::Kwalitee->import();

__END__

