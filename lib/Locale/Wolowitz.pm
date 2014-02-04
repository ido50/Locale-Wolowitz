package Locale::Wolowitz;

# ABSTRACT: Dead simple localization for with JSON.

use warnings;
use strict;
use utf8;
use feature "state";

use Moo;

use Type::Params qw( compile );
use Types::Standard qw( slurpy Object Str HashRef ArrayRef );

use Carp;
use JSON::Any;

our $VERSION = "0.4";
$VERSION = eval $VERSION;

=encoding utf-8

=head1 NAME

Locale::Wolowitz - Dead simple localization for with JSON.

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

	my $w = Locale::Wolowitz->new( path => './i18n' );

	print $w->loc('Welcome!', 'es'); # prints 'Bienvenido!'

	print $w->loc("I'm using %1", 'he', $w->loc('Linux', 'he')); # prints "אני משתמש בלינוקס"

=head1 DESCRIPTION

Locale::Wolowitz is a very simple text localization system. Yes, another
localization system.

Frankly, I never realized how to use the standard Perl localization systems
such as L<Locale::Maketext>, L<Gettext>, L<Data::Localize> or whatever.
It seems they are more meant to localize an application to the language
of the system on which its running, which isn't really what I need. Most of the
time, seeing as how I'm mostly writing web applications, I wish to localize
my applications/websites according to the user's wishes, not by the system.
For example, I may create a content management system where the user can
select the interface's language. Also, I grew to hate the standard .po
files, and thought using a JSON format might be more comfortable.

Locale::Wolowitz allows you to provide different languages to end-users of your
applications. To some extent, when writing RESTful web applications, this means
you can perform language negotiation with visitors (see
L<Content negotiation on Wikipedia|https://secure.wikimedia.org/wikipedia/en/w/index.php?title=Content_negotiation&oldid=367120431>).

Locale::Wolowitz works with JSON files. Each file can serve one or more languages.
When creating an instance of this module, you are required to pass a path
to a directory where your application's JSON localization files are present.
These are all loaded and merged into one big hash-ref (unless you tell the module
to only load a specific file), which is stored in memory. A file with only one
language has to be named <lang>.json (where <lang> is the name of the language,
you'd probably want to use the two-letter ISO 639-1 code). A file with multiple
languages must end with .coll.json (this requirement will probably be lifted in
the future).

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
		"Linux": {} // this line can also be missing entirely
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

Notice the "%1" substrings above. This is a placeholder, just like in other
localization paradigms - they are replaced with content you provide, usually
dynamic content. In Locale::Wolowitz, placeholders are written with a percent
sign, followed by an integer, starting from 1 (e.g. %1, %2, %3). When passing
data for the placeholders, make sure you're passing scalars, or printable
objects, otherwise you'll encounter errors.

We can also see here that Spanish and Dutch have no translation for "Linux".
Since Linux is written "Linux" in these languages, they have no translation.
When attempting to translate a string that has no translation to the requested
language, or has no reference in the JSON files at all, the string is
simply returned as is (but placeholders will still be replaced as expected).

Say you write your application in English (and thus 'en' is your base
language). Since Locale::Wolowitz doesn't really know what your base language is,
you can translate texts within the same language. This is more useful when
you want to give some of your strings an identifier. For example:

	"copyrights": {
		"en": "Copyrights, 2010 Ido Perlmuter",
		"he": "כל הזכויות שמורות, 2010 עידו פרלמוטר"
	}

=cut

=attr path

ro, Str. Specified the path of translations. It's required.

=cut

has path => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has locales => (
    is       => 'lazy',
    init_arg => undef,
    isa      => HashRef,
);

sub _build_locales {
    my ( $self ) = @_;

    return Locale::Wolowitz->_load_locales($self->path);
}

=head1 OBJECT METHODS

=head2 loc( $msg, $lang, [@args] )

Returns the string C<$msg>, translated to the requested language (if such
a translation exists, otherwise no traslation occurs). Any other parameters
passed to the method (C<@args>) are injected to the placeholders in the string
(if present).

=cut

sub loc {
        state $check = compile( Object, Str, Str, slurpy ArrayRef );
	my ($self, $msg, $lang, $args) = $check->(@_);

	return unless defined $msg; # undef strings are passed back as-is
	return $msg unless $lang;

	my $ret = $self->locales->{$msg} && $self->locales->{$msg}->{$lang}
            ? $self->locales->{$msg}->{$lang}
            : $msg;

	if (scalar @{$args}) {
		for (my $i = 1; $i <= scalar @{$args}; $i++) {
			$ret =~ s/%$i/$args->[$i-1]/g;
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

	my @files;

	if (-d $path) {
		# open the locales directory
		opendir(PATH, $path)
			|| croak "Can't open localization directory: $!";
	
		# get all JSON files
		@files = grep {/\.json$/} readdir PATH;

		closedir PATH
			|| carp "Can't close localization directory: $!";
	} elsif (-e $path) {
		my ($file) = ($path =~ m{/([^/]+)$})[0];
		$path = $`;
		@files = ($file);
	} else {
		croak "Path must be to a directory or a JSON file.";
	}

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

=head1 DIAGNOSTICS

The following exceptions are thrown by this module:

=over

=item C<< "You must provide a path to localization directory." >>

This exception is thrown if you haven't provided the C<new()> subroutine
a path to a localization file, or a directory of localization files. Read
the documentation for the C<new()> subroutine above.

=item C<< "Can't open localization directory: %s" and "Can't close localization directory: %s" >>

This exception is thrown if Locale::Wolowitz failed to open/close the directory
of the localization files. This will probably happen due to permission
problems. The error message should include the actual reason for the failure.

=item C<< "Path must be to a directory or a JSON file." >>

This exception is thrown if you passed a wrong value to the C<new()> subroutine
as the path to the localization directory/file. Either the path is wrong and thus
does not exist, or the path does exist, but is not a directory and not a file.

=item C<< "Can't open localization file %s: %s" and "Can't close localization file %s: %s" >>

This exception is thrown if Locale::Wolowitz fails to open/close a specific localization
file. This will usually happen because of permission problems. The error message
will include both the name of the file, and the actual reason for the failure.

=back

=head1 CONFIGURATION AND ENVIRONMENT
  
C<Locale::Wolowitz> requires no configuration files or environment variables.

=head1 DEPENDENCIES

C<Locale::Wolowitz> B<depends> on the following CPAN modules:

=over

=item * L<Carp>

=item * L<JSON::Any>

=back

C<Locale::Wolowitz> recommends L<JSON> and/or L<JSON::XS>
for actually being able to parse the JSON files.

=head1 INCOMPATIBILITIES WITH OTHER MODULES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-Locale-Wolowitz@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Locale-Wolowitz>.

=head1 AUTHOR

Ido Perlmuter <ido@ido50.net>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010-2012, Ido Perlmuter C<< ido@ido50.net >>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself, either version
5.8.1 or any later version. See L<perlartistic|perlartistic> 
and L<perlgpl|perlgpl>.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
__END__
