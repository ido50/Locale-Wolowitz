#!/usr/bin/perl -w

use warnings;
use strict;
use Wolowitz;
use Getopt::Compact;
use Carp;

# define program usage with Getopt::Compact
my $go = new Getopt::Compact(
	name	=> 'Wolowitz Data Localization',
	args	=> 'localization_path',
	struct	=> [
		[[qw(a action)], "action to perform (only 'update_files' for now)", ':s'],
	],
);

croak $go->usage unless $ARGV[0];

my $opts = $go->opts;
$opts->{action} ||= 'update_files';
$opts->{path} = $ARGV[0];

if ($opts->{action} eq 'update_files') {
	# search for ->loc('...' in the current working directory recursively
}
