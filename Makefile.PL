
# $Id: Makefile.PL,v 1.1 2009/02/23 07:36:16 aff Exp $

use strict;
use warnings;

require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME          => 'Parse::Dia::SQL',
  AUTHOR        => 'Andreas Faafeng <aff@cpan.org>',
  VERSION_FROM  => 'lib/Parse/Dia/SQL.pm',
  ABSTRACT_FROM => 'lib/Parse/Dia/SQL.pm',
  EXE_FILES     => ['bin/parsediasql'],
  PL_FILES      => {},
  PREREQ_PM     => {
    'Data::Dumper'              => 0,
    'Digest::MD5'               => 0,
    'Fatal'                     => 0,
    'File::Spec::Functions'     => 0,
    'File::Temp'                => 0,
    'File::Find'                => 0,
    'Getopt::Long'              => 0,
    'IO::Uncompress::Gunzip'    => 0,
    'Log::Dispatch::FileRotate' => 0,
    'Log::Log4perl'             => 0,
    'POSIX'                     => 0,
    'Test::Exception'           => 0,
    'Test::More'                => 0,
    'Text::Table'               => 0,
    'XML::DOM'                  => 0,
  },
  dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
  clean => { FILES    => 'Dia-SQL-*' },
);
