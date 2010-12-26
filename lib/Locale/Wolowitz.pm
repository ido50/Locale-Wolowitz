package Locale::Wolowitz;

# ABSTRACT: Dead simple localization for web apps with JSON.

use warnings;
use strict;
use JSON::Any;
use utf8;
use Carp;

=encoding utf-8

=head1 NAME

Locale::Wolowitz - Dead simple localization for web apps with JSON.

=head1 SYNOPSIS

	# in ./i18n/locales.coll.json
	{
		"Welcome!": {
			"he": "ברוכים הבאים!",
			"es": "Bienvenido!"
		},
		"I'm using %1": {
			"he": "אני משתמש ב%1",
			"es": "Estoy usando %1"
		},
		"Linux": {
			"he": "לינוקס"
		}
	}

	# in your app
	use Locale::Wolowitz;

	my $w = Locale::Wolowitz->new( './i18n' );

	print $w->loc('Welcome!', 'es'); # prints 'Bienvenido!'

	print $w->loc("I'm using %1", 'he', $w->loc('Linux', 'he')); # prints "אני משתמש בלינוקס"

=head1 DESCRIPTION

Locale::Wolowitz is a very simple text localization system, meant to be used by
web applications (but can pretty much be used anywhere). Yes, another
localization system.

Frankly, I never realized how to use the standard Perl localization systems
such as L<Locale::Maketext>, L<Gettext>, L<Data::Localize> or whatever.
It seems they are more meant to localize an application to the language
of the system on which its running, which isn't really what I need. I want
to allow users of my web applications (to put it simply, visitors of a
website backed by one of my web apps) to view my app/website in the language
of their choice. Also, I grew to hate the standard .po files, and thought
using a JSON format might be more comfortable. And so Wolowitz was born.

Locale::Wolowitz allows you to provide different languages to end-users of your
applications. To some extent, this means you can perform language negotiation
with visitors (see L<Content negotiation on Wikipedia|https://secure.wikimedia.org/wikipedia/en/w/index.php?title=Content_negotiation&oldid=367120431>).

Locale::Wolowitz works with JSON files. Each file can serve one or more languages.
When creating an instance of this module, you are required to pass a path
to a directory where your application's JSON localization files are present.
These are all loaded and merged into one big hash-ref, which is stored in
memory. A file with only one language has to be named <lang>.json (where
<lang> is the name of the language, you'd probably want to use the two-letter
ISO 639-1 code). A file with multiple languages must end with .coll.json
(this requirement will probably be lifted in the future).

The basic idea is to write your application in a base language, and use
the JSON files to translate text to other languages. For example, lets say
you're writing your application in English and translating it to Hebrew,
Spanish, and Dutch. You put Spanish and Dutch translations in one file,
and since everybody hates Israel, you put Hebrew translations alone.
The Spanish and Dutch file can look like this:

	# es_and_nl.coll.json
	{
		"Welcome!": {
			"es": "Bienvenido!",
			"nl": "Welkom!"
		},
		"I'm using %1": {
			"es": "Estoy usando %1",
			"nl": "Ik gebruik %1"
		},
		"Linux": {}
	}

While the Hebrew file can look like this:

	# he.json
	{
		"Welcome!": "ברוכים הבאים!",
		"I'm using %1": "אני משתמש ב%1",
		"Linux": "לינוקס"
	}

When loading these files, Locale::Wolowitz internally merges the two files into
one structure:

	{
		"Welcome!" => {
			"es" => "Bienvenido!",
			"nl" => "Welkom!",
			"he" => "ברוכים הבאים!",
		},
		"I'm using %1" => {
			"es" => "Estoy usando %1",
			"nl" => "Ik gebruik %1",
			"he" => "אני משתמש ב%1",
		},
		"Linux" => {
			"he" => "לינוקס",
		}
	}

We can see here that Spanish and Dutch have no translation for "Linux".
Since Linux is written "Linux" in these languages, they have no translation.
When attempting to translate a string that has no translation to the requested
language, or has no reference in the JSON files at all, the string is
simply returned as is.

Say you write your application in English (and thus 'en' is your base
language). Since Locale::Wolowitz doesn't really know what your base language is,
you can translate texts within the same language. This is more useful when
you want to give some of your strings an identifier. For example:

	"copyrights": {
		"en": "Copyrights, 2010 Ido Perlmuter",
		"he": "כל הזכויות שמורות, 2010 עידו פרלמוטר"
	}

As you've probably already noticed, Wolowitz supports placeholders.
In Locale::Wolowitz, placeholders are written with a percent sign, followed by
an integer, starting from 1 (e.g. %1, %2, %3). These are replaced by
whatever you're passing to the C<loc()> method (but make sure you're
passing scalars, or printable objects, otherwise you'll encounter errors).

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
passed to the method (C<@args>) are injected to the placeholders in the string
(if present).

=cut

sub loc {
	my ($self, $msg, $lang, @args) = @_;

	return $msg unless $lang;

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

Loads all locale JSON files in the directory C<$path> and returns them
as a hash-ref.

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

	my $locales = {};

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
		} elsif (m/\.json$/) { # has to be true
			my $lang = $`;
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

Please report any bugs or feature requests to C<bug-locale-wolowitz at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Locale-Wolowitz>. I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Locale::Wolowitz

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Locale-Wolowitz>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Locale-Wolowitz>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Locale-Wolowitz>

=item * Search CPAN

L<http://search.cpan.org/dist/Locale-Wolowitz/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
