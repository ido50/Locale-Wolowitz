package Wolowitz;

# ABSTRACT: Simple, JSON-based localization for web apps.

use warnings;
use strict;
use Carp;
use JSON::Any;

=head1 NAME

Wolowitz - Simple, JSON-based localization for web apps.

=head1 SYNOPSIS

	use Wolowitz;

	my $foo = Wolowitz->new();
	...

=head1 DESCRIPTION

=head1 CLASS METHODS

=head2 new( $path )

Creates a new instance of this module. Requires a path to a directory in
which JSON localization files exist. They will be automatically loaded.

=cut

sub new {
	my ($class, $path) = @_;

	return bless {
		path => $path,
		locales => $class->_load_locales($path)
	}, $class;
}

=head1 OBJECT METHODS

=head2 loc( $msg, $lang, [@args] )

Returns the string C<$msg>, translated to the requested language (if such
a translation exists, otherwise no traslation occurs). Any other parameters
passed to the method are injected to the placeholders in the string (if
present).

=cut

sub loc {
	my ($self, $msg, $lang, @args) = @_;

	my $ret = $self->{locales}->{$msg} && $self->{locales}->{$msg}->{$lang} ? $self->{locales}->{$msg}->{$lang} : $msg;

	if (scalar @args) {
		for (my $i = 1; $i <= scalar @args; $i++) {
			$ret =~ s/%$i/$args[$i-1]/g;
		}
	}

	return $ret;
}

=head1 INTERNAL METHODS

=head2 _load_locales( $path )

=cut

sub _load_locales {
	my ($class, $path) = @_;

	croak "You must provide a path to localization directory."
		unless $path;

	croak "Localization directory does not exist or is not a directory."
		unless -d $path;

	# open the locales directory
	opendir(PATH, $path)
		|| croak "Can't open localization directory: $!";
	
	# get all JSON files
	my @files = grep {/\.json$/} readdir PATH;

	closedir PATH
		|| carp "Can't close localization directory: $!";

	my $locales;

	# load the files
	foreach (@files) {
		# read the file's contents and parse it as json
		open(FILE, "$path/$_")
			|| croak "Can't open localization file $_: $!";
		undef $/;
		my $json = <FILE>;
		close FILE
			|| carp "Can't close localization file $_: $!";
		
		my $data = JSON::Any->from_json($json);
		
		# is this a one-lang file or a collection?
		if (m/\.coll\.json$/) {
			# this is a collection of languages
			foreach my $str (keys %$data) {
				foreach my $lang (keys %{$data->{$str}}) {
					$locales->{$str}->{$lang} = $data->{$str}->{$lang};
				}
			}
		} else {
			# get lang from file name
			my ($lang) = (m/^(.+)\.json$/);
			foreach my $str (keys %$data) {
				$locales->{$str}->{$lang} = $data->{$str};
			}
		}
	}

	return $locales;
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wolowitz at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Wolowitz>. I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Wolowitz

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Wolowitz>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Wolowitz>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Wolowitz>

=item * Search CPAN

L<http://search.cpan.org/dist/Wolowitz/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
