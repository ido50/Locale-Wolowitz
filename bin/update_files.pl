#!/usr/bin/perl -w

use warnings;
use strict;
use Wolowitz;
use Carp;

my $path = $ARGV[0];

croak "You must provide a path to the localization directory."
	unless $path;

