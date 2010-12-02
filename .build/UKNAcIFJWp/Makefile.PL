
use strict;
use warnings;

BEGIN { require 5.008; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Simple localization for web apps.',
  'AUTHOR' => 'Ido Perlmuter <ido@ido50.net>',
  'BUILD_REQUIRES' => {
    'Test::More' => '0',
    'utf8' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Wolowitz',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Wolowitz',
  'PREREQ_PM' => {
    'Carp' => '0',
    'JSON::Any' => '0'
  },
  'VERSION' => '0.1',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



